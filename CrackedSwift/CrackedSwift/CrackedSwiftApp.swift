//
//  CrackedSwiftApp.swift
//  CrackedSwift
//
//  Main entry point - replaces Unity's scene management
//

import SwiftUI

@main
struct CrackedSwiftApp: App {
    // Initialize managers early
    @StateObject private var gameData = GameDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(gameData)
                .background(ScenePhaseHandler())
        }
    }
}

/// Shows main app only after Screen Time setup is complete; otherwise shows blocking setup screen.
/// Screen Time gate disabled — using Darwin lock detection instead (Flora-style).
struct RootView: View {
    @EnvironmentObject var gameData: GameDataManager
    // @ObservedObject private var screenTime = ScreenTimeManager.shared
    
    var body: some View {
        ContentView()
        // Screen Time setup gate commented out — no longer needed.
        // Group {
        //     if screenTime.hasCompletedSetup {
        //         ContentView()
        //     } else {
        //         ScreenTimeRequiredView()
        //     }
        // }
    }
}

// Separate view to handle scene phase monitoring
struct ScenePhaseHandler: View {
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Color.clear
            .onChange(of: scenePhase) { oldPhase, newPhase in
                Task { @MainActor in
                    let appState = UIApplication.shared.applicationState
                    
                    switch newPhase {
                    case .inactive:
                        // App becoming inactive (e.g., lock button pressed)
                        // Check if it's likely phone sleep or app switching
                        if appState == .inactive {
                            // Phone is likely going to sleep - pause timer temporarily
                            TimerManager.shared.handleAppBecomingInactive()
                        }
                    case .background:
                        // App went to background - determine if sleep or app switch
                        TimerManager.shared.handleAppBackgrounded()
                    case .active:
                        // App came back to foreground
                        if oldPhase == .inactive || oldPhase == .background {
                            TimerManager.shared.handleAppForegrounded()
                        }
                    @unknown default:
                        break
                    }
                }
        }
    }
}

