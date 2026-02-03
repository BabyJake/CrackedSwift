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
/// Expected activity name for our focus session
private let focusActivityName = "focusSession"

class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        // Only respond to our focus session activity
        guard activity.rawValue == focusActivityName else {
            print("[CrackedSwift] ⚠️ Device Activity extension — ignoring event for unknown activity: \(activity.rawValue)")
            return
        }
        
        // User used a monitored app → set violation flag
        // Main app will only crack if it actually went to background (backgroundStartTime != nil)
        print("[CrackedSwift] 🔴 LEFT APP (Screen Time): Device Activity extension — user used monitored app (event: \(event.rawValue)), setting violation flag")
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(true, forKey: sessionViolatedKey)
        defaults.synchronize()
    }
}
