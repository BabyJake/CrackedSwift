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

    // MARK: - Cleanup

    /// End **every** running `TimerAttributes` Live Activity.
    /// Call this on app launch (when no timer is active) and whenever we want
    /// to guarantee no orphaned activities remain on the Lock Screen / Dynamic Island.
    func endAllActivities() {
        guard #available(iOS 16.1, *) else { return }

        let running = Activity<TimerAttributes>.activities
        guard !running.isEmpty else { return }

        print("🧹 [LiveActivity] Ending \(running.count) stale activity(ies)")

        let finalState = TimerAttributes.ContentState(
            timeRemaining: 0,
            endDate: Date(),
            isRunning: false
        )

        for act in running {
            Task {
                let staleDate = Date().addingTimeInterval(1)
                await act.end(
                    ActivityContent(state: finalState, staleDate: staleDate),
                    dismissalPolicy: .immediate
                )
                print("  ✅ Ended stale activity \(act.id)")
            }
        }

        // Clear our tracked reference as well
        activity = nil
    }

    func startLiveActivity(eggName: String, eggImageName: String, duration: TimeInterval) {
        guard #available(iOS 16.1, *) else { return }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ [LiveActivity] Activities are not enabled")
            return
        }

        // End ALL existing activities (including orphans from previous launches).
        endAllActivities()

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

        // When timer reaches 0, update state so widget can show "ready to hatch" / "ready to empty"
        let effectiveRemaining = max(0, timeRemaining)
        let endDate = (isRunning && timeRemaining > 0) ? Date().addingTimeInterval(timeRemaining) : Date()
        let updatedContentState = TimerAttributes.ContentState(
            timeRemaining: effectiveRemaining,
            endDate: endDate,
            isRunning: isRunning && timeRemaining > 0
        )

        Task { @MainActor in
            do {
                await activity.update(ActivityContent(state: updatedContentState, staleDate: endDate))
            } catch {
                print("❌ [LiveActivity] Error updating activity: \(error.localizedDescription)")
                if timeRemaining <= 0 {
                    self.activity = nil
                }
            }
        }
    }

    func endLiveActivity() {
        guard #available(iOS 16.1, *) else { return }

        // End all activities (covers both the tracked one and any orphans).
        endAllActivities()
    }
}
