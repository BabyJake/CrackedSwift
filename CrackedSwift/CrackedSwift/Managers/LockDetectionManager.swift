//
//  LockDetectionManager.swift
//  CrackedSwift
//
//  Flora-style screen lock detection using the "com.apple.springboard.lockcomplete"
//  Darwin notification. When the device locks, isScreenLocked becomes true.
//  TimerManager reads this flag to distinguish "phone sleep" from "intentional leave."
//

import Foundation

// The notify_* C API lives in <notify.h>. On iOS the module isn't named
// "Darwin.notify" — we pull it in with a bridging typealias-free approach:
// declare the three symbols we need directly from libSystem.
//
// notify_register_dispatch, notify_cancel, NOTIFY_STATUS_OK
private let NOTIFY_STATUS_OK: UInt32 = 0

@_silgen_name("notify_register_dispatch")
private func _notify_register_dispatch(
    _ name: UnsafePointer<CChar>,
    _ out_token: UnsafeMutablePointer<Int32>,
    _ queue: DispatchQueue,
    _ handler: @escaping @convention(block) (Int32) -> Void
) -> UInt32

@_silgen_name("notify_cancel")
private func _notify_cancel(_ token: Int32) -> UInt32

@MainActor
class LockDetectionManager {
    static let shared = LockDetectionManager()

    /// `true` after the device-lock Darwin notification fires.
    /// Reset by the foreground handler after each background→foreground cycle.
    private(set) var isScreenLocked: Bool = false

    private var notifyToken: Int32 = 0
    private var isRegistered: Bool = false

    private init() {
        registerForLockNotification()
    }

    // MARK: - Darwin Notification

    private func registerForLockNotification() {
        guard !isRegistered else { return }

        // notify_register_dispatch is a public C API (Darwin / libSystem).
        // "com.apple.springboard.lockcomplete" fires whenever the device locks
        // (side-button press or auto-lock timeout).
        let status = _notify_register_dispatch(
            "com.apple.springboard.lockcomplete",
            &notifyToken,
            DispatchQueue.main
        ) { (token: Int32) in
            // The C callback runs on DispatchQueue.main; hop to MainActor for isolation.
            Task { @MainActor in
                LockDetectionManager.shared.isScreenLocked = true
                print("[CrackedSwift] 🔒 Darwin: Screen lock detected (lockcomplete)")
            }
        }

        isRegistered = (status == NOTIFY_STATUS_OK)
        if isRegistered {
            print("[CrackedSwift] ✅ Registered for com.apple.springboard.lockcomplete")
        } else {
            print("[CrackedSwift] ❌ Failed to register for lock notification (status \(status))")
        }
    }

    // MARK: - State Management

    /// Reset after the foreground handler has read the flag so the next
    /// background→foreground cycle starts clean.
    func resetLockState() {
        isScreenLocked = false
    }

    deinit {
        if isRegistered {
            _ = _notify_cancel(notifyToken)
        }
    }
}
