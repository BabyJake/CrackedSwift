//
//  DeviceActivityMonitorExtension.swift
//  DeviceActivityExtension
//
//  Screen Time–based leave-app detection. When the user uses a monitored app
//  during a focus session, we set a flag; the main app cracks the egg/shatters
//  piggybank on return. Locking the phone does not set the flag.
//

import DeviceActivity
import Foundation

/// App Group shared with main app (must match main app entitlements).
private let appGroupID = "group.Cracked.CrackedSwift"
/// UserDefaults key the main app checks on foreground.
private let sessionViolatedKey = "focusSessionViolated"
/// UserDefaults key: when the violation was set (prevents old violations from triggering crack).
private let lastViolationTimestampKey = "focusSessionLastViolationTimestamp"
/// Expected activity name for our focus session
private let focusActivityName = "focusSession"

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        // Only respond to our focus session activity
        guard activity.rawValue == focusActivityName else { return }

        // User used a monitored app → set violation flag and timestamp
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let timestamp = Date().timeIntervalSince1970
        defaults.set(true, forKey: sessionViolatedKey)
        defaults.set(timestamp, forKey: lastViolationTimestampKey)
        defaults.synchronize()
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
    }
}
