//
//  ScreenTimeManager.swift
//  Fauna
//
//  Swift version of ScreenTimeManager (replaces the Objective-C bridge)
//

import Foundation
import FamilyControls
import DeviceActivity

@MainActor
class ScreenTimeManager {
    static let shared = ScreenTimeManager()
    
    private init() {}

    /// Becomes `true` once we've finished the initial authorization request flow
    /// (regardless of whether the user granted or denied).
    private(set) var didFinishAuthorizationRequest: Bool = false
    
    func requestAuthorization() async {
        defer { didFinishAuthorizationRequest = true }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            print("✅ Screen Time authorization granted")
        } catch {
            print("❌ Failed to get authorization: \(error)")
        }
    }
}

