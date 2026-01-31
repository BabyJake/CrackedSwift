//
//  FaunaApp.swift
//  Fauna
//
//  Main entry point - replaces Unity's scene management
//

import SwiftUI

struct FaunaApp: App {
    // Initialize managers early
    @StateObject private var gameData = GameDataManager.shared
    
    init() {
        // Request Screen Time authorization on app launch
        Task {
            await ScreenTimeManager.shared.requestAuthorization()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameData)
        }
    }
}

