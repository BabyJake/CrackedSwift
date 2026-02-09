//
//  ContentView.swift
//  Fauna
//
//  Main navigation - replaces MenuManager.cs scene switching
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gameData: GameDataManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MenuView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            ShopView()
                .tabItem {
                    Image(systemName: "cart.fill")
                    Text("Shop")
                }
                .tag(1)
            
            SanctuaryView()
                .tabItem {
                    Image(systemName: "pawprint.fill")
                    Text("Sanctuary")
                }
                .tag(2)
        }
        .alert("Study Streak!", isPresented: Binding(
            get: { gameData.streakAlertInfo?.show ?? false },
            set: { if !$0 { gameData.dismissStreakAlert() } }
        )) {
            Button("Awesome!") {
                gameData.dismissStreakAlert()
            }
        } message: {
            if let info = gameData.streakAlertInfo {
                Text("\(info.message)\n\nStreak: \(info.streak) day\(info.streak == 1 ? "" : "s")\nReward: \(info.reward) coins 🪙")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameDataManager.shared)
}

