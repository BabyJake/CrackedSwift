//
//  FocusSessionConstants.swift
//  CrackedSwift
//
//  Shared constants for Screen Time–based leave-app detection.
//  Used by main app and Device Activity Monitor extension (same string values).
//

import Foundation

enum FocusSessionConstants {
    /// App Group for sharing "session violated" flag between main app and Device Activity extension.
    static let appGroupID = "group.Cracked.CrackedSwift"

    /// UserDefaults key: true when user used a monitored app for the threshold duration (egg/piggybank should crack on return).
    static let sessionViolatedKey = "focusSessionViolated"

    /// DeviceActivity schedule name used when starting focus monitoring.
    static let activityName = "focusSession"

    /// DeviceActivityEvent names for "left app" threshold (apps and categories monitored separately).
    static let leaveAppAppsEventName = "leaveAppApps"
    static let leaveAppCategoriesEventName = "leaveAppCategories"

    /// Seconds of usage in a monitored app before we consider the session "left" (crack/shatter). 1 = instant.
    static let leaveAppThresholdSeconds = 1

    /// Minimum DeviceActivity schedule length (API requirement). We use max(this, timer duration).
    static let minimumScheduleSeconds = 15 * 60
}
