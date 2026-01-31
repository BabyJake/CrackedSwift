//
//  TimerAttributes.swift
//  CrackedSwift
//
//  Created for Live Activities support.
//

import ActivityKit
import Foundation

/// Live Activity attributes for the study timer.
///
/// This file must compile in the main app target. A matching `TimerAttributes`
/// type also exists in the widget extension target so ActivityKit can render it.
struct TimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Remaining time at the moment we last updated state (used for paused UI).
        var timeRemaining: TimeInterval

        /// When the timer is running, the UI can count down to this date without
        /// requiring per-second updates from the app.
        var endDate: Date

        var isRunning: Bool
    }

    // Static data that doesn't change for the activity.
    var eggName: String
    var eggImageName: String
    var totalDuration: TimeInterval
    var startDate: Date
}
