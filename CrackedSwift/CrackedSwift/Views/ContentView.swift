//
//  ContentView.swift
//  Fauna
//
//  Main navigation - replaces MenuManager.cs scene switching
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gameData: GameDataManager
    @StateObject private var tutorial = TutorialManager.shared
    @State private var selectedTab = 0
    @State private var tutorialEggSelection = false
    @State private var tutorialHatchedAnimal: Animal?
    @State private var showingTutorialHatchResult = false
    
    var body: some View {
        ZStack {
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
            .tabViewStyle(.tabBarOnly)
            
            // Tutorial overlay — only shows for welcome, sanctuary, and shop steps
            TutorialOverlayView()
        }
        // Tutorial egg-selection sheet — triggered when user taps nest during tapNest step
        .sheet(isPresented: $tutorialEggSelection, onDismiss: {
            // After egg selection dismisses, check if we should show hatch result
            if tutorial.currentStep == .instantHatch && tutorialHatchedAnimal != nil {
                showingTutorialHatchResult = true
            }
        }) {
            TutorialEggSelectionView(onInstantHatch: {
                tutorialHatchedAnimal = tutorial.performInstantHatch()
                tutorial.next() // → .instantHatch
            })
        }
        .sheet(isPresented: $showingTutorialHatchResult, onDismiss: {
            // After dismissing hatch result, advance to Sanctuary step
            if tutorial.isActive {
                tutorial.next() // → showSanctuary
            }
        }) {
            if let animal = tutorialHatchedAnimal {
                TutorialHatchView(animal: animal) {
                    showingTutorialHatchResult = false
                }
            }
        }
        .onChange(of: tutorial.requestEggSelection) { _, shouldOpen in
            if shouldOpen {
                tutorial.requestEggSelection = false
                tutorialEggSelection = true
            }
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
        .onAppear {
            tutorial.switchTab = { tab in
                withAnimation { selectedTab = tab }
            }
            tutorial.startIfNeeded()
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
                                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
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

// MARK: - Tutorial Helper Views

/// Simplified hatch result shown during the tutorial instant-hatch step.
struct TutorialHatchView: View {
    let animal: Animal
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            AppColors.backgroundGreen
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Text("🎉 You hatched an animal!")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Animal image
                Group {
                    if UIImage(named: animal.imageName) != nil {
                        Image(animal.imageName)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(width: 180, height: 180)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .cornerRadius(20)
                
                VStack(spacing: 4) {
                    Text(animal.name)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if let animalData = AnimalDatabase.getAnimalData(for: animal.name) {
                        Text(animalData.rarity.rawValue.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.color(for: animalData.rarity))
                    }
                }
                
                Text("Complete study sessions to hatch more animals for your sanctuary!")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppColors.buttonGreen)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
    }
}

/// A simplified egg selection sheet shown during the tutorial.
/// Cards are directly interactive — no overlay. User taps each card
/// to learn about it and advance the tutorial.
struct TutorialEggSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var tutorial = TutorialManager.shared
    @State private var pulse = false
    
    /// Called when user taps the FarmEgg during `.selectEgg` to trigger the hatch.
    var onInstantHatch: (() -> Void)?
    
    var body: some View {
        ZStack {
            AppColors.backgroundGreen
                .ignoresSafeArea()
            
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Your Eggs")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    // Step-specific instruction banner
                    tutorialBanner
                    
                    // Piggybank card
                    tutorialEggCard(
                        title: "Piggybank",
                        icon: "🐷",
                        imageName: "PiggyBank",
                        description: "Earns 2× coins but won't hatch an animal. Great for saving up!",
                        isHighlighted: tutorial.currentStep == .showPiggybank,
                        isDimmed: tutorial.currentStep == .selectEgg
                    ) {
                        if tutorial.currentStep == .showPiggybank {
                            tutorial.next() // → selectEgg
                        }
                    }
                    
                    // FarmEgg card
                    tutorialEggCard(
                        title: "Farm Egg",
                        icon: "🌾",
                        imageName: "FarmEgg",
                        description: "Contains common farm animals. Hatch one now!",
                        isHighlighted: tutorial.currentStep == .selectEgg,
                        isDimmed: tutorial.currentStep == .showPiggybank
                    ) {
                        if tutorial.currentStep == .selectEgg {
                            onInstantHatch?()
                            dismiss()
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .background(AppColors.backgroundGreen)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Skip") {
                            dismiss()
                            tutorial.finish()
                        }
                        .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .onAppear { pulse = true }
    }
    
    // MARK: - Instruction Banner
    
    @ViewBuilder
    private var tutorialBanner: some View {
        switch tutorial.currentStep {
        case .showPiggybank:
            bannerView(
                icon: "hand.tap.fill",
                text: "Tap the Piggybank to learn about it!"
            )
        case .selectEgg:
            bannerView(
                icon: "sparkles",
                text: "Now tap the Farm Egg to hatch instantly!"
            )
        default:
            EmptyView()
        }
    }
    
    private func bannerView(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.yellow)
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Egg Card
    
    @ViewBuilder
    private func tutorialEggCard(
        title: String,
        icon: String,
        imageName: String,
        description: String,
        isHighlighted: Bool,
        isDimmed: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Egg image
                Group {
                    if UIImage(named: imageName) != nil {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Text(icon)
                            .font(.system(size: 40))
                    }
                }
                .frame(width: 70, height: 70)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isHighlighted {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                        .scaleEffect(pulse ? 1.15 : 0.9)
                        .animation(
                            .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                            value: pulse
                        )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isHighlighted ? 0.15 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isHighlighted ? Color.yellow.opacity(0.7) : Color.white.opacity(0.1),
                        lineWidth: isHighlighted ? 2 : 1
                    )
                    .scaleEffect(isHighlighted && pulse ? 1.02 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: pulse
                    )
            )
            .opacity(isDimmed ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDimmed)
    }
}

#Preview {
    ContentView()
        .environmentObject(GameDataManager.shared)
}
