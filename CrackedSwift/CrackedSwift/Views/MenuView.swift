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
    @State private var crackedGrave: Animal?
    @State private var isGiveUpGrave = false
    @State private var showingNoEggAlert = false
    @State private var initialTimerDuration: TimeInterval = 0
    @State private var showingStreakRewards = false
    @State private var showingPiggybankShatteredAlert = false
    @State private var showingPiggybankResult = false
    @State private var showingLeaveAppSelection = false
    
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
    
    var body: some View {
        ZStack {
            // Main background color (dark forest green)
            AppColors.backgroundGreen
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar with streak and coins
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
                    
                    // Coin counter (top-right)
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
                            isGiveUpGrave = false // Reset flag when starting new timer
                            
                            // Set up callbacks
                            timerManager.onTimerComplete = { studyDuration in
                                handleTimerComplete(studyDuration: studyDuration)
                            }
                            timerManager.onCoinsAwarded = { coins in
                                coinsEarned = coins
                            }
                            timerManager.onEggCracked = { grave in
                                crackedGrave = grave
                                // isGiveUpGrave is already set in the give up button action
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
                    
                    // Egg Selection Button (only show when timer is not running)
                    if !timerManager.isTimerRunning {
                        Button(action: {
                            showingEggSelection = true
                        }) {
                            HStack {
                                Text("Current Egg: \(shopManager.getCurrentEgg() ?? "None")")
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                        }
                        // Screen Time: apps that count as "leaving" (lock screen does not crack)
                        Button(action: {
                            showingLeaveAppSelection = true
                        }) {
                            HStack {
                                Image(systemName: "app.badge")
                                Text(ScreenTimeManager.shared.hasSelectedApps ? "Apps that count as leaving (set)" : "Set apps that count as leaving")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .padding(.bottom, 100)
                
                Spacer()
                
                // Circular slider with draggable knob
                CircularSlider(
                    selectedMinutes: $selectedMinutes,
                    isTimerRunning: $timerManager.isTimerRunning,
                    timeRemaining: timerManager.timeRemaining,
                    initialDuration: initialTimerDuration,
                    currentEggImageName: currentEggImageName
                )
                    .padding(.bottom, 40)
            }
            .alert("Give Up Session?", isPresented: $showingGiveUpAlert) {
                Button("Yes", role: .destructive) {
                    isGiveUpGrave = true
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
                    crackedGrave = nil
                    isGiveUpGrave = false
                }
            } message: {
                if let grave = crackedGrave {
                    if isGiveUpGrave {
                        Text("You gave up on your study session. Your egg has cracked and became a grave. You did not receive any coins.")
                    } else {
                        Text("You left the app while studying. Your egg has cracked and became a grave. You earned partial coins for the time you spent.")
                    }
                } else {
                    Text("You left the app while studying. Your egg has cracked.")
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
            .sheet(isPresented: $showingLeaveAppSelection) {
                LeaveAppSelectionView(isPresented: $showingLeaveAppSelection)
            }
        }
    }
    
    private func handleTimerComplete(studyDuration: TimeInterval) {
        // Check if piggybank mode - if so, just show coins, no animal hatching
        if let currentEgg = shopManager.getCurrentEgg(), currentEgg == "Piggybank" {
            // Piggybank mode: show completion screen with coins earned
            hatchedAnimal = nil
            showingHatchResult = false
            showingPiggybankResult = true
            initialTimerDuration = 0
            return
        }
        
        // Normal egg mode: Hatch the egg - this is successful completion
        // Pass study duration to boost rare animal spawn chances
        let currentEggTitle = shopManager.getCurrentEgg()
        if let animal = animalManager.hatchEgg(studyDuration: studyDuration) {
            hatchedAnimal = animal
            showingHatchResult = true
            
            // Check if the current egg type is now exhausted
            if let currentEgg = currentEggTitle, !gameData.hasEgg(currentEgg) {
                // No more eggs of this type, automatically select the next available egg
                if let nextEgg = shopManager.getNextAvailableEgg(excluding: currentEgg) {
                    shopManager.selectEgg(nextEgg)
                }
            }
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
            // Debug: Print available eggs
            let purchasedEggs = gameData.getPurchasedEggs()
            print("DEBUG: Purchased eggs: \(purchasedEggs)")
            print("DEBUG: Available eggs count: \(availableEggs.count)")
            for eggData in availableEggs {
                print("DEBUG: Egg '\(eggData.egg.title)' quantity: \(eggData.quantity)")
            }
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
    
    var body: some View {
        ZStack {
            AppColors.backgroundGreen
                .ignoresSafeArea()
            
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        // Current streak display
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 24))
                            
                            Text("Current Streak: \(gameData.getCurrentStreak())")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .padding(.top)
                        
                        // Potential rewards for upcoming days
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Potential Rewards")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            // Show rewards for current streak and next few days
                            ForEach(0..<7) { offset in
                                let day = gameData.getCurrentStreak() + offset
                                let reward = gameData.getPotentialReward(for: day)
                                
                                RewardRowView(
                                    day: day,
                                    coins: reward.coins,
                                    eggName: reward.egg
                                )
                            }
                        }
                        .padding()
                    }
                }
                .background(AppColors.backgroundGreen)
                .navigationTitle("Streak Rewards")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppColors.backgroundGreen, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
            }
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
            // Day number
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
                        // Show egg image if available
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

