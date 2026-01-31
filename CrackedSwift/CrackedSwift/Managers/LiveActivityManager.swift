//
//  LiveActivityManager.swift
//  CrackedSwift
//
//  Created for Live Activities support.
//

import Foundation
import ActivityKit

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activity: Activity<TimerAttributes>?

    private init() {}

    func startLiveActivity(eggName: String, eggImageName: String, duration: TimeInterval) {
        guard #available(iOS 16.1, *) else { return }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ [LiveActivity] Activities are not enabled")
            return
        }

        // If one is already running, end it first (avoid duplicates).
        if activity != nil {
            endLiveActivity()
        }

        let startDate = Date()
        let endDate = startDate.addingTimeInterval(duration)

        let attributes = TimerAttributes(
            eggName: eggName,
            eggImageName: eggImageName,
            totalDuration: duration,
            startDate: startDate
        )

        let initialContentState = TimerAttributes.ContentState(
            timeRemaining: duration,
            endDate: endDate,
            isRunning: true
        )

        do {
            // Mark stale once the timer should have finished.
            let activityContent = ActivityContent(state: initialContentState, staleDate: endDate)

            activity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )

            print("✅ [LiveActivity] Started activity: \(activity?.id ?? "unknown")")
        } catch {
            print("❌ [LiveActivity] Error starting activity: \(error.localizedDescription)")
        }
    }

    func updateLiveActivity(timeRemaining: TimeInterval, isRunning: Bool) {
        guard #available(iOS 16.1, *) else { return }
        guard let activity else { return }

        let endDate = isRunning ? Date().addingTimeInterval(timeRemaining) : Date()
        let updatedContentState = TimerAttributes.ContentState(
            timeRemaining: timeRemaining,
            endDate: endDate,
            isRunning: isRunning
        )

        Task {
            await activity.update(ActivityContent(state: updatedContentState, staleDate: endDate))
        }
    }

    func endLiveActivity() {
        guard #available(iOS 16.1, *) else { return }
        guard let activity else { return }

        let finalContentState = TimerAttributes.ContentState(
            timeRemaining: 0,
            endDate: Date(),
            isRunning: false
        )

        Task {
            await activity.end(
                ActivityContent(state: finalContentState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            self.activity = nil
        }
    }
}
