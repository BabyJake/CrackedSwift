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
    
    init() {
        // Request permissions first, then show streak alert
        Task { @MainActor in
            await ScreenTimeManager.shared.requestAuthorization()
            GameDataManager.shared.checkAndUpdateStreak()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameData)
                .background(ScenePhaseHandler())
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
                        // Only show streak after the initial permission flow is finished
                        if ScreenTimeManager.shared.didFinishAuthorizationRequest {
                            GameDataManager.shared.checkAndUpdateStreak()
                        }
                    @unknown default:
                        break
                    }
                }
        }
    }
}

