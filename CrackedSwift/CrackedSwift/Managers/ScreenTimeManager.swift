//
//  ScreenTimeManager.swift
//  Fauna
//
//  Swift version of ScreenTimeManager (replaces the Objective-C bridge).
//  Uses Device Activity (Screen Time) API to detect "left app" vs "phone sleep":
//  only crack/shatter when user uses a monitored app (instant), not when locking the device.
//

import Foundation
import FamilyControls
import DeviceActivity

@MainActor
class ScreenTimeManager {
    static let shared = ScreenTimeManager()
    
    private let center = DeviceActivityCenter()
    private let appGroupDefaults = UserDefaults(suiteName: FocusSessionConstants.appGroupID)
    private let selectionKey = "focusSessionAppSelection"
    
    private init() {}

    /// Becomes `true` once we've finished the initial authorization request flow
    /// (regardless of whether the user granted or denied).
    private(set) var didFinishAuthorizationRequest: Bool = false
    
    /// Whether the user has selected at least one app/category for "leave app" detection.
    var hasSelectedApps: Bool {
        guard let data = appGroupDefaults?.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return false
        }
        return !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }
    
    func requestAuthorization() async {
        defer { didFinishAuthorizationRequest = true }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            print("✅ Screen Time authorization granted")
        } catch {
            print("❌ Failed to get authorization: \(error)")
        }
    }
    
    /// Save the user's app selection (from FamilyActivityPicker). Used for leave-app detection.
    func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        appGroupDefaults?.set(data, forKey: selectionKey)
    }
    
    /// Load the saved app selection for display in the picker.
    func loadSelection() -> FamilyActivitySelection? {
        guard let data = appGroupDefaults?.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return nil
        }
        return selection
    }
    
    /// Start Screen Time–based monitoring for the focus session. When the user uses any selected app
    /// as soon as they use a monitored app, the Device Activity extension sets the violation flag; we crack on return.
    /// Call when the timer starts (only if hasSelectedApps and authorization granted).
    func startFocusMonitoring(timerDurationSeconds: TimeInterval) {
        clearViolationFlag()
        guard hasSelectedApps,
              let selectionData = appGroupDefaults?.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData) else {
            return
        }
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        if apps.isEmpty && categories.isEmpty { return }
        
        let activityName = DeviceActivityName(rawValue: FocusSessionConstants.activityName)
        let scheduleLength = max(TimeInterval(FocusSessionConstants.minimumScheduleSeconds), timerDurationSeconds)
        let endDate = Date().addingTimeInterval(scheduleLength)
        let cal = Calendar.current
        let startComponents = cal.dateComponents([.calendar, .year, .month, .day, .hour, .minute, .second], from: Date())
        let endComponents = cal.dateComponents([.calendar, .year, .month, .day, .hour, .minute, .second], from: endDate)
        let schedule = DeviceActivitySchedule(intervalStart: startComponents, intervalEnd: endComponents, repeats: false)
        
        let threshold = DateComponents(second: FocusSessionConstants.leaveAppThresholdSeconds)
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        if !apps.isEmpty {
            events[DeviceActivityEvent.Name(FocusSessionConstants.leaveAppAppsEventName)] = DeviceActivityEvent(applications: apps, threshold: threshold)
        }
        if !categories.isEmpty {
            events[DeviceActivityEvent.Name(FocusSessionConstants.leaveAppCategoriesEventName)] = DeviceActivityEvent(categories: categories, threshold: threshold)
        }
        guard !events.isEmpty else { return }
        
        do {
            try center.startMonitoring(activityName, during: schedule, events: events)
            clearViolationFlag()
            print("[CrackedSwift] ✅ Focus monitoring started (Screen Time) — leaving to a monitored app will set violation")
        } catch {
            print("[CrackedSwift] ❌ Failed to start focus monitoring: \(error)")
        }
    }
    
    /// Stop Screen Time monitoring. Call when the timer ends (complete, give up, or crack).
    func stopFocusMonitoring() {
        let activityName = DeviceActivityName(rawValue: FocusSessionConstants.activityName)
        center.stopMonitoring([activityName])
        clearViolationFlag()
        print("[CrackedSwift] ⏹ Focus monitoring stopped (Screen Time)")
    }
    
    /// Check and consume the violation flag (set by Device Activity extension when user used a monitored app).
    /// Returns true if the session was violated so the timer should crack/shatter.
    func checkAndClearViolation() -> Bool {
        guard let defaults = appGroupDefaults else { return false }
        let violated = defaults.bool(forKey: FocusSessionConstants.sessionViolatedKey)
        if violated {
            print("[CrackedSwift] 🔴 LEFT APP (Screen Time): Main app read violation flag → will crack/shatter")
            clearViolationFlag()
        }
        return violated
    }
    
    private func clearViolationFlag() {
        appGroupDefaults?.set(false, forKey: FocusSessionConstants.sessionViolatedKey)
    }
}

