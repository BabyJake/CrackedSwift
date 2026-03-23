//
//  MenuView.swift
//  Fauna
//
//  Replaces: Menu scene and MenuManager.cs
//

import SwiftUI
import UIKit

struct MenuView: View {
    @EnvironmentObject var gameData: GameDataManager
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var shopManager = ShopManager.shared
    @StateObject private var animalManager = AnimalManager.shared
    
    @State private var selectedMinutes: Int = 30
    @State private var showingEggSelection = false
    @State private var showingHatchResult = false
    @State private var hatchedAnimal: Animal?
    @State private var coinsEarned = 0
    @State private var showingGiveUpAlert = false
    @State private var showingEggCrackedAlert = false
    @State private var crackedShell: Animal?
    @State private var isGiveUpShell = false
    @State private var showingNoEggAlert = false
    @State private var initialTimerDuration: TimeInterval = 0
    @State private var showingStreakRewards = false
    @State private var showingPiggybankShatteredAlert = false
    @State private var showingPiggybankResult = false
    @State private var showingAccount = false
    @State private var sliderIsDragging = false
    @State private var showRarityRing = false
    @State private var ringFadeWorkItem: DispatchWorkItem?
    // Screen Time settings UI commented out — using Darwin lock detection instead.
    // @State private var showingSettings = false
    
    // Computed property to get current egg image name
    private var currentEggImageName: String {
        if let currentEggTitle = shopManager.getCurrentEgg() {
            if currentEggTitle == "Piggybank" {
                return "Piggybank" // Use piggybank image if available, fallback handled in CircularSlider
            }
            if let egg = shopManager.getEggByTitle(currentEggTitle) {
                return egg.imageName
            }
        }
        return "FarmEgg" // Default fallback
    }
    
    // Rarity distribution for the ring (empty for Piggybank)
    private var currentRarityDistribution: [RarityTierChance] {
        let currentEggTitle = shopManager.getCurrentEgg() ?? "FarmEgg"
        if currentEggTitle == "Piggybank" { return [] }
        return animalManager.getRarityDistribution(eggTitle: currentEggTitle, studyMinutes: Double(selectedMinutes))
    }
    
    var body: some View {
        ZStack {
            // Main background color (dark forest green)
            AppColors.backgroundGreen
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with streak, coins, and settings
                HStack {
                    // Streak indicator (top-left) - clickable
                    Button(action: {
                        showingStreakRewards = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 18))
                            
                            Text("\(gameData.getCurrentStreak())")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                    }
                    
                    Spacer()
                    
                    // Coin counter and account button (top-right)
                    HStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Text("Coins: \(gameData.getTotalCoins())")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            // Coin icon placeholder
                            Image(systemName: "circle.fill")
                                .foregroundColor(AppColors.coinGold)
                                .overlay(
                                    Image(systemName: "pawprint.fill")
                                        .foregroundColor(AppColors.coinBrown)
                                        .font(.system(size: 12))
                                )
                                .frame(width: 24, height: 24)
                        }
                        
                        // Account / profile button
                        Button(action: {
                            showingAccount = true
                        }) {
                            Image(systemName: AuthManager.shared.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                                .foregroundColor(.white)
                                .font(.system(size: 22))
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 40)
                
                Spacer()
                
                // Timer section
                VStack(spacing: 30) {
                    // Timer display
                    Text(timerManager.isTimerRunning ? timerManager.formattedTime() : formatSelectedTime(selectedMinutes))
                        .font(.system(size: 72, weight: .bold, design: .monospaced))
                        .foregroundColor(timerManager.isTimerRunning ? .red : .white)
                    
                    // Start Timer button
                    if !timerManager.isTimerRunning {
                        Button(action: {
                            // Prevent starting timer at 0 minutes
                            guard selectedMinutes > 0 else { return }
                            
                            let duration = TimeInterval(selectedMinutes * 60)
                            initialTimerDuration = duration
                            isGiveUpShell = false // Reset flag when starting new timer
                            
                            // Set up callbacks
                            timerManager.onTimerComplete = { studyDuration in
                                handleTimerComplete(studyDuration: studyDuration)
                            }
                            timerManager.onCoinsAwarded = { coins in
                                coinsEarned = coins
                            }
                            timerManager.onEggCracked = { shell in
                                crackedShell = shell
                                // isGiveUpShell is already set in the give up button action
                                showingEggCrackedAlert = true
                                initialTimerDuration = 0
                            }
                            timerManager.onPiggybankShattered = {
                                showingPiggybankShatteredAlert = true
                                initialTimerDuration = 0
                            }
                            
                            // Close egg selection menu if open
                            showingEggSelection = false
                            
                            // Start timer (consumes an egg)
                            if !timerManager.startTimer(duration: duration) {
                                showingNoEggAlert = true
                            }
                        }) {
                            Text("Start Timer")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 200, height: 56)
                                .background(selectedMinutes > 0 ? AppColors.buttonGreen : Color.gray)
                                .cornerRadius(28) // Very rounded corners
                        }
                        .disabled(selectedMinutes <= 0)
                    } else {
                        // Timer running - show control buttons
                        Button(action: {
                            showingGiveUpAlert = true
                        }) {
                            Text("Give Up")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                    }
                    
                }
                .padding(.bottom, 100)
                
                Spacer()
                
                // Circular slider with rarity ring
                VStack(spacing: 8) {
                    ZStack {
                        // Rarity chance ring (outermost) — fades in on drag, fades out after
                        if !currentRarityDistribution.isEmpty {
                            RarityRingView(distribution: currentRarityDistribution)
                                .opacity(showRarityRing ? 1 : 0)
                                .animation(.easeInOut(duration: 0.35), value: showRarityRing)
                        }
                        
                        CircularSlider(
                            selectedMinutes: $selectedMinutes,
                            isTimerRunning: $timerManager.isTimerRunning,
                            isDragging: $sliderIsDragging,
                            timeRemaining: timerManager.timeRemaining,
                            initialDuration: initialTimerDuration,
                            currentEggImageName: currentEggImageName,
                            hasEggSelected: shopManager.getCurrentEgg() != nil,
                            onEggTap: { showingEggSelection = true }
                        )
                    }
                    .frame(width: 330, height: 330)
                    .onChange(of: sliderIsDragging) { _, dragging in
                        ringFadeWorkItem?.cancel()
                        if dragging {
                            withAnimation { showRarityRing = true }
                        } else {
                            // Fade out after 1.5 seconds of inactivity
                            let work = DispatchWorkItem {
                                withAnimation { showRarityRing = false }
                            }
                            ringFadeWorkItem = work
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
                        }
                    }
                    
                    // Rarity legend — also fades with ring
                    if !timerManager.isTimerRunning && !currentRarityDistribution.isEmpty {
                        RarityLegendView(distribution: currentRarityDistribution)
                            .opacity(showRarityRing ? 1 : 0)
                            .animation(.easeInOut(duration: 0.35), value: showRarityRing)
                    }
                }
                .padding(.bottom, 20)
            }
            .alert("Give Up Session?", isPresented: $showingGiveUpAlert) {
                Button("Yes", role: .destructive) {
                    isGiveUpShell = true
                    timerManager.giveUpSession()
                    initialTimerDuration = 0
                }
                Button("No", role: .cancel) {}
            } message: {
                Text(timerManager.isCurrentSessionPiggybank ? "Your piggybank will shatter and you will lose the coins you earned this session." : "Your egg will crack and you won't receive any coins.")
            }
            .alert("Piggybank Shattered!", isPresented: $showingPiggybankShatteredAlert) {
                Button("OK") {
                    showingPiggybankShatteredAlert = false
                }
            } message: {
                Text("You left the app or gave up while studying with the piggybank. Your piggybank shattered and you lost the coins you earned this session.")
            }
            .alert("Egg Cracked!", isPresented: $showingEggCrackedAlert) {
                Button("OK") {
                    crackedShell = nil
                    isGiveUpShell = false
                }
            } message: {
                if let shell = crackedShell {
                    if isGiveUpShell {
                        Text("You gave up on your session. Your egg cracked and left behind a shell. No coins were earned.")
                    } else {
                        Text("You left the app during your session. Your egg cracked and left behind a shell. You earned partial coins for the time you focused.")
                    }
                } else {
                    Text("You left the app during your session. Your egg has cracked.")
                }
            }
            .alert("No Egg Available", isPresented: $showingNoEggAlert) {
                Button("OK") {}
            } message: {
                Text("You need to have at least one egg purchased and selected to start a study session.")
            }
            .sheet(isPresented: $showingEggSelection) {
                EggSelectionView()
            }
            .sheet(isPresented: $showingHatchResult) {
                if let animal = hatchedAnimal {
                    HatchResultView(animal: animal, coinsEarned: coinsEarned)
                }
            }
            .sheet(isPresented: $showingPiggybankResult) {
                PiggybankResultView(coinsEarned: coinsEarned)
            }
            .sheet(isPresented: $showingStreakRewards) {
                StreakRewardsView()
            }
            .sheet(isPresented: $showingAccount) {
                AccountView()
            }
            // Screen Time settings sheet commented out — no longer needed.
            // .sheet(isPresented: $showingSettings) {
            //     SettingsView()
            // }
        }
    }
    
    private func handleTimerComplete(studyDuration: TimeInterval) {
        // Check if piggybank mode - if so, just show coins, no animal hatching
        if let currentEgg = shopManager.getCurrentEgg(), currentEgg == "Piggybank" {
            // Piggybank mode: show completion screen with coins earned
            hatchedAnimal = nil
            showingHatchResult = false
            showingPiggybankResult = true
            gameData.clearCurrentEgg()
            initialTimerDuration = 0
            return
        }
        
        // Normal egg mode: Hatch the egg - this is successful completion
        // Pass study duration to boost rare animal spawn chances
        let currentEggTitle = shopManager.getCurrentEgg()
        if let animal = animalManager.hatchEgg(studyDuration: studyDuration) {
            hatchedAnimal = animal
            showingHatchResult = true
            
            // Egg was consumed — clear selection so EmptyEgg shows in the nest
            // User must pick a new egg before starting another session
            gameData.clearCurrentEgg()
        }
        initialTimerDuration = 0
    }
    
    private func formatSelectedTime(_ minutes: Int) -> String {
        let totalSeconds = minutes * 60
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}


struct EggSelectionView: View {
    @StateObject private var shopManager = ShopManager.shared
    @StateObject private var gameData = GameDataManager.shared
    @Environment(\.dismiss) var dismiss
    
    // Get all available eggs with their quantities
    var availableEggs: [(egg: Egg, quantity: Int)] {
        var eggs: [(egg: Egg, quantity: Int)] = []
        let purchasedEggs = gameData.getPurchasedEggs()
        
        // Add Piggybank (always available, show as 1)
        let piggybankEgg = Egg(
            title: "Piggybank",
            description: "Earn coins without hatching animals",
            baseCost: 0,
            imageName: "PiggyBank"
        )
        eggs.append((egg: piggybankEgg, quantity: 1))
        
        // Add purchased eggs - show each egg individually based on quantity
        for (eggTitle, quantity) in purchasedEggs {
            if quantity > 0 {
                if let egg = shopManager.getEggByTitle(eggTitle) {
                    // Add the egg with its quantity - the view will show multiple instances
                    eggs.append((egg: egg, quantity: quantity))
                } else {
                    // Debug: print if egg not found
                    print("Warning: Egg '\(eggTitle)' not found in shop database. Purchased quantity: \(quantity)")
                }
            }
        }
        
        return eggs
    }
    
    // Helper function to create egg image view
    @ViewBuilder
    private func eggImageView(for egg: Egg) -> some View {
        if egg.title == "Piggybank" {
            if UIImage(named: "PiggyBank") != nil {
                Image("PiggyBank")
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "oval.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.8))
            }
        } else if UIImage(named: egg.imageName) != nil {
            Image(egg.imageName)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "oval.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // Helper function to create a single egg button (instanceId identifies which card when there are multiple of same type)
    @ViewBuilder
    private func singleEggButton(for egg: Egg, instanceId: String) -> some View {
        let coinsPerMin = egg.title == "Piggybank" ? TimerManager.displayCoinsPerMinute * 2 : TimerManager.displayCoinsPerMinute
        let currentInstanceId = shopManager.getCurrentEggInstanceId()
        let isSelected = shopManager.getCurrentEgg() == egg.title && (currentInstanceId == nil || currentInstanceId == instanceId)
        
        Button(action: {
            shopManager.selectEgg(egg.title, instanceId: instanceId)
            dismiss()
        }) {
            
            VStack(spacing: 6) {
                ZStack {
                    eggImageView(for: egg)
                        .frame(width: 100, height: 100)
                    
                    if isSelected {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.buttonGreen)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .font(.system(size: 20))
                                    .padding(4)
                            }
                        }
                    }
                }
                
                HStack(spacing: 2) {
                    Image(systemName: "circle.fill")
                        .foregroundColor(AppColors.coinGold)
                        .overlay(
                            Image(systemName: "pawprint.fill")
                                .foregroundColor(AppColors.coinBrown)
                                .font(.system(size: 6))
                        )
                        .font(.system(size: 10))
                    Text("\(coinsPerMin)/min")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? AppColors.buttonGreen : Color.white.opacity(0.3),
                        lineWidth: isSelected ? 3 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    var body: some View {
        ZStack {
            AppColors.backgroundGreen
                .ignoresSafeArea()
            
            NavigationView {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100), spacing: 16)
                    ], spacing: 16) {
                        ForEach(Array(availableEggs.enumerated()), id: \.offset) { index, eggData in
                            // Show multiple instances of the same egg based on quantity
                            ForEach(0..<eggData.quantity, id: \.self) { quantityIndex in
                                let instanceId = "\(eggData.egg.id)-\(quantityIndex)"
                                singleEggButton(for: eggData.egg, instanceId: instanceId)
                                    .id(instanceId)
                            }
                        }
                    }
                    .padding()
                }
                .background(AppColors.backgroundGreen)
                .navigationTitle("Select Egg")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppColors.backgroundGreen, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
        }
        .onAppear {
            // Egg selection appeared — no-op (debug prints removed to reduce memory churn)
        }
    }
}

struct HatchResultView: View {
    let animal: Animal
    let coinsEarned: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            AppColors.backgroundGreen
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("🎉 Egg Hatched!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Animal image
                Group {
                    if UIImage(named: animal.imageName) != nil {
                        Image(animal.imageName)
                            .resizable()
                            .scaledToFit()
                    } else {
                        // Placeholder if image not found
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(width: 200, height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
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
                
                Text("+\(coinsEarned) Coins")
                    .font(.headline)
                    .foregroundColor(.yellow)
                
                // TODO: Re-enable "Watch Ad to Double Coins" button once ads are implemented
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppColors.buttonGreen)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
            }
            .padding()
        }
    }
}

struct PiggybankResultView: View {
    let coinsEarned: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            AppColors.backgroundGreen
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("🎉 Coins Saved!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("You completed your study session!\nYour piggy bank is full.")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Piggy bank / coins image
                Group {
                    if UIImage(named: "Piggybank") != nil {
                        Image("Piggybank")
                            .resizable()
                            .scaledToFit()
                    } else if UIImage(named: "PiggyBank") != nil {
                        Image("PiggyBank")
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 80))
                            .foregroundColor(AppColors.coinGold)
                    }
                }
                .frame(width: 200, height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Text("+\(coinsEarned) Coins")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                
                // TODO: Re-enable "Watch Ad to Double Coins" button once ads are implemented
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppColors.buttonGreen)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
            }
            .padding()
        }
    }
}

struct StreakRewardsView: View {
    @StateObject private var gameData = GameDataManager.shared
    @StateObject private var shopManager = ShopManager.shared
    @Environment(\.dismiss) var dismiss

    // Fixed milestone days shown on the roadmap
    private let milestones: [Int] = [1, 3, 7, 14, 30]

    var body: some View {
        ZStack {
            AppColors.backgroundGreen
                .ignoresSafeArea()

            NavigationView {
                ScrollView {
                    VStack(spacing: 24) {

                        // MARK: – Current streak badge
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)

                                Text("\(gameData.getCurrentStreak())")
                                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            Text("Day Streak")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 8)

                        // MARK: – This-week progress (days 1-7)
                        WeekProgressRow(currentStreak: gameData.getCurrentStreak())
                            .padding(.horizontal)

                        // MARK: – Milestone roadmap
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Milestone Rewards")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .padding(.bottom, 12)

                            ForEach(Array(milestones.enumerated()), id: \.offset) { idx, day in
                                let reward = gameData.getPotentialReward(for: day)
                                let reached = gameData.getCurrentStreak() >= day
                                MilestoneRow(
                                    day: day,
                                    coins: reward.coins,
                                    eggName: reward.egg,
                                    reached: reached,
                                    isLast: idx == milestones.count - 1
                                )
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.06))
                        )
                        .padding(.horizontal)

                        // MARK: – Daily base info
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.white.opacity(0.5))
                            Text("You earn 25 coins every day you log in, plus milestone bonuses.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                .background(AppColors.backgroundGreen)
                .navigationTitle("Streak Rewards")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppColors.backgroundGreen, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

// MARK: – Week progress dots (Sun-Sat style)

private struct WeekProgressRow: View {
    let currentStreak: Int

    // How many of the last 7 days are "filled"
    private var filledDays: Int {
        min(currentStreak, 7)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("This Week")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 10) {
                ForEach(1...7, id: \.self) { day in
                    let filled = day <= filledDays
                    ZStack {
                        Circle()
                            .fill(filled
                                  ? LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom)
                                  : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                            .frame(width: 36, height: 36)
                        if filled {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(day)")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// MARK: – Single milestone row with connector line

private struct MilestoneRow: View {
    let day: Int
    let coins: Int
    let eggName: String?
    let reached: Bool
    let isLast: Bool
    @StateObject private var shopManager = ShopManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Left: circle + vertical connector
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(reached
                              ? LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [Color.white.opacity(0.15), Color.white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)

                    if reached {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(day)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }

                if !isLast {
                    Rectangle()
                        .fill(reached ? Color.orange.opacity(0.5) : Color.white.opacity(0.1))
                        .frame(width: 3, height: 40)
                }
            }

            // Right: reward info
            VStack(alignment: .leading, spacing: 6) {
                Text("Day \(day)")
                    .font(.headline)
                    .foregroundColor(reached ? .white : .white.opacity(0.6))

                HStack(spacing: 10) {
                    // Egg reward
                    if let eggName = eggName, let egg = shopManager.getEggByTitle(eggName) {
                        HStack(spacing: 4) {
                            if UIImage(named: egg.imageName) != nil {
                                Image(egg.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26, height: 26)
                            }
                            Text(eggName)
                                .font(.subheadline)
                                .foregroundColor(reached ? .white.opacity(0.9) : .white.opacity(0.5))
                        }
                    }

                    // Coin reward
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(AppColors.coinGold)
                            .font(.system(size: 10))
                        Text("+\(coins)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(reached ? AppColors.coinGold : AppColors.coinGold.opacity(0.5))
                    }
                }
            }
            .padding(.top, 8)

            Spacer()
        }
    }
}

struct RewardRowView: View {
    let day: Int
    let coins: Int
    let eggName: String?
    @StateObject private var shopManager = ShopManager.shared

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Text("\(day)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Day \(day)")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    if let eggName = eggName, let egg = shopManager.getEggByTitle(eggName) {
                        Group {
                            if UIImage(named: egg.imageName) != nil {
                                Image(egg.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                            } else {
                                Image(systemName: "oval.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 20))
                            }
                        }

                        Text(eggName)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }

                    if coins > 0 {
                        if eggName != nil {
                            Text("+")
                                .foregroundColor(.white.opacity(0.7))
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .foregroundColor(AppColors.coinGold)
                                .font(.system(size: 12))
                            Text("\(coins)")
                                .font(.subheadline)
                                .foregroundColor(AppColors.coinGold)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    MenuView()
        .environmentObject(GameDataManager.shared)
}

