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
    @StateObject private var authManager = AuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(gameData)
                .environmentObject(authManager)
                .background(ScenePhaseHandler())
                .task {
                    authManager.checkCredentialState()
                    await CloudKitManager.shared.syncOnLaunch()
                    
                    // One-time cleanup of schema seed records — remove after one run
                    await CloudKitSchemaSeeder.cleanupSeedRecords()
                }
        }
    }
}

/// Shows the one-time account prompt if the user hasn't signed in or skipped,
/// then the one-time display name prompt after sign-in,
/// then shows the main app.
struct RootView: View {
    @EnvironmentObject var gameData: GameDataManager
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        if !authManager.hasSeenAccountPrompt && !authManager.isSignedIn {
            // Step 1: Show sign-in / skip prompt
            AccountPromptView()
        } else if authManager.isSignedIn && !authManager.hasSetDisplayName {
            // Step 2: One-time display name choice (right after first sign-in)
            DisplayNamePromptView()
        } else {
            // Step 3: Main app
            ContentView()
        }
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

