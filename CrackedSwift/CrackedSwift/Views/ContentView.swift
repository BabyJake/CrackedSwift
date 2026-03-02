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
            
            LeaderboardTabView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Leaderboard")
                }
                .tag(3)
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

/// Wrapper so LeaderboardView is presented as a full tab (not a sheet)
struct LeaderboardTabView: View {
    @StateObject private var leaderboard = LeaderboardManager.shared
    
    @State private var selectedScope: LeaderboardScope = .global
    @State private var selectedCategory: LeaderboardCategory = .animalsHatched
    @State private var showingAddFriend = false
    @State private var showingFriendsList = false
    @State private var showingMyProfile = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGreen
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Scope picker
                    Picker("Scope", selection: $selectedScope) {
                        ForEach(LeaderboardScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Category picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LeaderboardCategory.allCases) { category in
                                CategoryChip(
                                    category: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    withAnimation { selectedCategory = category }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    
                    // Friend requests banner
                    if !leaderboard.incomingRequests.isEmpty {
                        Button {
                            showingFriendsList = true
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("\(leaderboard.incomingRequests.count) friend request\(leaderboard.incomingRequests.count == 1 ? "" : "s")")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.orange.opacity(0.3))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Leaderboard list
                    if leaderboard.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("Loading...")
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 8)
                        Spacer()
                    } else {
                        let entries = selectedScope == .global
                            ? leaderboard.sortedEntries(leaderboard.globalEntries, by: selectedCategory)
                            : leaderboard.sortedEntries(leaderboard.friendEntries, by: selectedCategory)
                        
                        if entries.isEmpty {
                            Spacer()
                            VStack(spacing: 16) {
                                Image(systemName: selectedScope == .friends ? "person.2.slash" : "chart.bar")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                if selectedScope == .friends {
                                    Text("No friends yet!")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("Add friends by searching their username\nto see how you compare.")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                    
                                    Button {
                                        showingAddFriend = true
                                    } label: {
                                        Label("Add a Friend", systemImage: "person.badge.plus")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(AppColors.buttonGreen)
                                            .cornerRadius(12)
                                    }
                                } else {
                                    Text("No leaderboard data yet")
                                        .font(.title3)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("Complete a study session to appear here!")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                        LeaderboardRow(
                                            rank: index + 1,
                                            entry: entry,
                                            category: selectedCategory,
                                            isMe: entry.id == leaderboard.myUserID
                                        )
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                            }
                            .refreshable {
                                await leaderboard.pushStats()
                                await leaderboard.refreshAll()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingMyProfile = true
                        } label: {
                            Label("My Username", systemImage: "person.circle")
                        }
                        
                        Button {
                            showingAddFriend = true
                        } label: {
                            Label("Add Friend", systemImage: "person.badge.plus")
                        }
                        
                        Button {
                            showingFriendsList = true
                        } label: {
                            Label("Friends (\(leaderboard.friends.count))", systemImage: "person.2")
                        }
                        
                        Divider()
                        
                        Button {
                            Task {
                                await leaderboard.pushStats()
                                await leaderboard.refreshAll()
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView()
            }
            .sheet(isPresented: $showingFriendsList) {
                FriendsListView()
            }
            .sheet(isPresented: $showingMyProfile) {
                MyUsernameView()
            }
            .task {
                await leaderboard.setup()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GameDataManager.shared)
}

