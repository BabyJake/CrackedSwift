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
import Combine

// MARK: - Potential future feature: Block (shield) all selected apps during a focus session
// To enable: add `import ManagedSettings`, create `private let managedStore = ManagedSettingsStore()`,
// and in startFocusMonitoring (after decoding selection) add:
//   managedStore.shield.applications = Set(apps)
//   if !categories.isEmpty { managedStore.shield.applicationCategories = .specific(Set(categories)) }
// In stopFocusMonitoring add:
//   managedStore.shield.applications = nil
//   managedStore.shield.applicationCategories = .none
// This uses Screen Time's shield so the user cannot open blocked apps during a session.

@MainActor
class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()
    
    private let center = DeviceActivityCenter()
    private let appGroupDefaults = UserDefaults(suiteName: FocusSessionConstants.appGroupID)
    private let selectionKey = "focusSessionAppSelection"
    private let totalAppCountKey = "focusSessionTotalAppCount"
    
    private init() {}

    /// Becomes `true` once we've finished the initial authorization request flow
    /// (regardless of whether the user granted or denied).
    private(set) var didFinishAuthorizationRequest: Bool = false
    
    /// `nil` = not yet requested, `true` = granted, `false` = denied.
    @Published private(set) var authorizationGranted: Bool? = nil
    
    /// Minimum apps even if device has very few apps (prevents gaming).
    private static let absoluteMinimumApps = 3
    
    /// Whether the user has properly selected apps to monitor.
    /// For initial setup: requires (total - 1) apps (all except Cracked).
    /// For settings: allows customization but requires at least 3 apps minimum.
    var hasSelectedApps: Bool {
        guard let data = appGroupDefaults?.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return false
        }
        
        let appCount = selection.applicationTokens.count
        
        // Must have at least minimum apps selected
        guard appCount >= Self.absoluteMinimumApps else {
            return false
        }
        
        // If we have a saved total from initial setup, prefer (total - 1) but allow less for customization
        if let totalAppCount = loadTotalAppCount(), totalAppCount > 0 {
            // Allow settings customization: require at least 3 apps, but prefer (total - 1)
            // This allows users to exclude more apps in settings while preventing abuse
            return appCount >= Self.absoluteMinimumApps
        }
        
        // No saved total (shouldn't happen after initial setup, but handle gracefully)
        return appCount >= Self.absoluteMinimumApps
    }
    
    /// Must be true before the user can use the app (authorization granted + at least one app selected).
    var hasCompletedSetup: Bool {
        authorizationGranted == true && hasSelectedApps
    }
    
    func requestAuthorization() async {
        defer { didFinishAuthorizationRequest = true }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationGranted = true
            print("✅ Screen Time authorization granted")
        } catch {
            authorizationGranted = false
            print("❌ Failed to get authorization: \(error)")
        }
    }
    
    /// Save the user's app selection and total app count (from FamilyActivityPicker).
    /// totalAppCount is the peak count recorded when user tapped "All Apps & Categories".
    func saveSelection(_ selection: FamilyActivitySelection, totalAppCount: Int) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        appGroupDefaults?.set(data, forKey: selectionKey)
        appGroupDefaults?.set(totalAppCount, forKey: totalAppCountKey)
        print("[ScreenTimeManager] Saved selection: \(selection.applicationTokens.count) apps, total: \(totalAppCount)")
        objectWillChange.send()
    }
    
    /// Load the saved app selection for display in the picker.
    func loadSelection() -> FamilyActivitySelection? {
        guard let data = appGroupDefaults?.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return nil
        }
        return selection
    }
    
    /// Load the saved total app count (the peak count from when user tapped "All").
    func loadTotalAppCount() -> Int? {
        let count = appGroupDefaults?.integer(forKey: totalAppCountKey) ?? 0
        return count > 0 ? count : nil
    }
    
    /// Start Screen Time–based monitoring for the focus session. When the user uses any selected app,
    /// the Device Activity extension sets the violation flag; we crack on return.
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
        // Add buffer to cover breaks (timer pauses but schedule doesn't), timer tick drift, and safety margin.
        // stopFocusMonitoring() is always called when the session actually ends, so extra time is harmless.
        let scheduleLength = max(TimeInterval(FocusSessionConstants.minimumScheduleSeconds), timerDurationSeconds + FocusSessionConstants.scheduleBufferSeconds)
        let endDate = Date().addingTimeInterval(scheduleLength)
        let cal = Calendar.current
        let startComponents = cal.dateComponents([.calendar, .year, .month, .day, .hour, .minute, .second], from: Date())
        let endComponents = cal.dateComponents([.calendar, .year, .month, .day, .hour, .minute, .second], from: endDate)
        let schedule = DeviceActivitySchedule(intervalStart: startComponents, intervalEnd: endComponents, repeats: false)
        
        let interval = FocusSessionConstants.leaveAppThresholdSeconds
        let seconds = Int(interval)
        let nanoseconds = Int((interval - Double(seconds)) * 1_000_000_000)
        let threshold = DateComponents(second: seconds, nanosecond: nanoseconds)
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
            print("[CrackedSwift] ✅ Focus monitoring started — leaving to a monitored app will set violation")
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
    /// Returns true only if the session was violated and the violation is recent (timestamp >= since, or since is nil).
    /// Pass backgroundStartTime to ignore stale violations from a previous session.
    func checkAndClearViolation(since: Date? = nil) -> Bool {
        guard let defaults = appGroupDefaults else { return false }
        let violated = defaults.bool(forKey: FocusSessionConstants.sessionViolatedKey)
        guard violated else {
            clearViolationFlag()
            return false
        }
        // Ignore old violations: require violation timestamp to be at or after we went to background
        if let sinceDate = since {
            let timestamp = defaults.double(forKey: FocusSessionConstants.lastViolationTimestampKey)
            guard timestamp >= sinceDate.timeIntervalSince1970 else {
                print("[CrackedSwift] ⚠️ Foreground: ignoring stale violation (timestamp \(timestamp) < background start)")
                clearViolationFlag()
                return false
            }
        }
        print("[CrackedSwift] 🔴 LEFT APP (Screen Time): Main app read violation flag → will crack/shatter")
        clearViolationFlag()
        return true
    }
    
    private func clearViolationFlag() {
        appGroupDefaults?.set(false, forKey: FocusSessionConstants.sessionViolatedKey)
        appGroupDefaults?.removeObject(forKey: FocusSessionConstants.lastViolationTimestampKey)
    }
}

