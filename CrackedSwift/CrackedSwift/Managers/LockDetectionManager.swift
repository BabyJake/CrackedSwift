//
//  LockDetectionManager.swift
//  CrackedSwift
//
//  Screen lock detection using public UIKit notifications.
//  When the device locks, isScreenLocked becomes true.
//  TimerManager reads this flag to distinguish "phone sleep" from "intentional leave."
//
//  Uses UIApplication.protectedDataWillBecomeUnavailableNotification (fires on device lock)
//  and UIApplication.protectedDataDidBecomeAvailableNotification (fires on unlock).
//  These are fully public APIs — no private SpringBoard notifications needed.
//

import UIKit

@MainActor
final class LockDetectionManager {
    static let shared = LockDetectionManager()

    /// `true` after the device-lock notification fires.
    /// Reset by the foreground handler after each background→foreground cycle.
    private(set) var isScreenLocked: Bool = false

    private init() {
        registerForLockNotifications()
    }

    // MARK: - Public API Lock Detection

    private func registerForLockNotifications() {
        // protectedDataWillBecomeUnavailable fires when the device locks
        // (passcode-protected devices — which is nearly all real devices).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProtectedDataUnavailable),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )

        // protectedDataDidBecomeAvailable fires when the device unlocks.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProtectedDataAvailable),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )

        print("[CrackedSwift] ✅ Registered for protectedData lock/unlock notifications (public API)")
    }

    // MARK: - Notification Handlers

    @objc private func handleProtectedDataUnavailable() {
        isScreenLocked = true
        print("[CrackedSwift] 🔒 Screen lock detected (protectedData unavailable)")
    }

    @objc private func handleProtectedDataAvailable() {
        // Note: we don't reset isScreenLocked here — TimerManager reads + resets it
        // explicitly via resetLockState() in handleAppForegrounded().
        print("[CrackedSwift] 🔓 Screen unlock detected (protectedData available)")
    }

    // MARK: - State Management

    /// Reset after the foreground handler has read the flag so the next
    /// background→foreground cycle starts clean.
    func resetLockState() {
        isScreenLocked = false
    }
}
