//
//  GameDataManager.swift
//  Fauna
//
//  Replaces: PlayerPrefs system
//

import Foundation

@MainActor
class GameDataManager: ObservableObject {
    static let shared = GameDataManager()
    
    @Published private(set) var gameData = GameData()
    @Published var streakAlertInfo: (show: Bool, streak: Int, reward: Int, message: String)? = nil
    
    private let userDefaults = UserDefaults.standard
    private let gameDataKey = "FaunaGameData"
    
    private init() {
        loadGameData()
    }
    
    // MARK: - Load/Save
    
    func loadGameData() {
        if let data = userDefaults.data(forKey: gameDataKey),
           let decoded = try? JSONDecoder().decode(GameData.self, from: data) {
            self.gameData = decoded
        } else {
            // New player - start with 1 FarmEgg
            gameData.purchasedEggs["FarmEgg"] = 1
            gameData.currentSelectedEgg = "FarmEgg"
            // Save locally only — don't push starter data to cloud
            // (syncOnLaunch will handle cloud restore vs push)
            saveLocalOnly()
        }
    }
    
    func saveGameData() {
        if let encoded = try? JSONEncoder().encode(gameData) {
            userDefaults.set(encoded, forKey: gameDataKey)
        }
        // Schedule debounced sync to CloudKit
        CloudKitManager.shared.scheduleSave(gameData: gameData)
    }
    
    /// Saves to UserDefaults only, without triggering a CloudKit sync.
    /// Used during initial setup to avoid overwriting cloud data before restore.
    private func saveLocalOnly() {
        if let encoded = try? JSONEncoder().encode(gameData) {
            userDefaults.set(encoded, forKey: gameDataKey)
        }
    }
    
    /// Replaces local game data with cloud data (used during cloud restore).
    /// Preserves any active timer state so CloudKit sync doesn't wipe a running session.
    func replaceGameData(_ newData: GameData) {
        // If there is an active timer session locally, preserve the timer
        // fields — the cloud copy almost certainly has stale/cleared timer state.
        var merged = newData
        if gameData.wasTimerRunning, gameData.savedSessionStartTime != nil {
            merged.savedTimeRemaining       = gameData.savedTimeRemaining
            merged.savedSessionStartTime    = gameData.savedSessionStartTime
            merged.wasTimerRunning           = gameData.wasTimerRunning
            merged.savedActiveEggTitle      = gameData.savedActiveEggTitle
            merged.savedIsPiggybankMode     = gameData.savedIsPiggybankMode
            merged.savedBackgroundTime      = gameData.savedBackgroundTime
            merged.savedInitialTimerDuration = gameData.savedInitialTimerDuration
            // Also preserve break state if active
            merged.isOnBreak                = gameData.isOnBreak
            merged.breakStartTime           = gameData.breakStartTime
            merged.lastBreakTime            = gameData.lastBreakTime
            print("☁️ [GameData] replaceGameData: preserved active timer state")
        }
        self.gameData = merged
        if let encoded = try? JSONEncoder().encode(merged) {
            userDefaults.set(encoded, forKey: gameDataKey)
        }
        objectWillChange.send()
    }
    
    /// Resets all local game data to a fresh state (used during account deletion).
    func resetAllData() {
        self.gameData = GameData()
        // Give the default starter egg
        gameData.purchasedEggs["FarmEgg"] = 1
        gameData.currentSelectedEgg = "FarmEgg"
        userDefaults.removeObject(forKey: gameDataKey)
        if let encoded = try? JSONEncoder().encode(gameData) {
            userDefaults.set(encoded, forKey: gameDataKey)
        }
        objectWillChange.send()
        print("🗑️ [GameData] All data reset to fresh state")
    }
    
    // MARK: - Coins
    
    func getTotalCoins() -> Int {
        return gameData.totalCoins
    }
    
    func addCoins(_ amount: Int) {
        gameData.totalCoins += amount
        saveGameData()
    }
    
    func spendCoins(_ amount: Int) -> Bool {
        guard gameData.totalCoins >= amount else {
            return false
        }
        gameData.totalCoins -= amount
        saveGameData()
        // Trigger published update by reassigning (ensures UI updates)
        objectWillChange.send()
        return true
    }
    
    /// Subtracts coins (e.g. when piggybank shatters — lose only session coins). Clamps to 0.
    func subtractCoins(_ amount: Int) {
        gameData.totalCoins = max(0, gameData.totalCoins - amount)
        saveGameData()
        objectWillChange.send()
    }
    
    // MARK: - Animals
    
    func addUnlockedAnimal(_ animalName: String) {
        if !gameData.unlockedAnimals.contains(animalName) {
            gameData.unlockedAnimals.append(animalName)
            saveGameData()
        }
    }
    
    func getUnlockedAnimals() -> [String] {
        return gameData.unlockedAnimals
    }
    
    func setPendingAnimal(_ animalName: String) {
        let pendingAnimal = GameData.PendingAnimal(animalName: animalName, hatchDate: Date())
        gameData.pendingAnimals.append(pendingAnimal)
        saveGameData()
    }
    
    func getPendingAnimals() -> [GameData.PendingAnimal] {
        return gameData.pendingAnimals
    }
    
    func clearPendingAnimal() {
        gameData.pendingAnimals.removeAll()
        saveGameData()
    }
    
    // MARK: - Eggs
    
    func purchaseEgg(_ eggTitle: String) {
        gameData.purchasedEggs[eggTitle, default: 0] += 1
        saveGameData()
    }
    
    func getPurchasedEggs() -> [String: Int] {
        return gameData.purchasedEggs
    }
    
    func setCurrentEgg(_ eggTitle: String, instanceId: String? = nil) {
        gameData.currentSelectedEgg = eggTitle
        gameData.currentSelectedEggInstanceId = instanceId
        saveGameData()
    }
    
    func getCurrentEgg() -> String? {
        return gameData.currentSelectedEgg
    }
    
    func clearCurrentEgg() {
        gameData.currentSelectedEgg = nil
        gameData.currentSelectedEggInstanceId = nil
        saveGameData()
    }
    
    func getCurrentEggInstanceId() -> String? {
        return gameData.currentSelectedEggInstanceId
    }
    
    func consumeEgg(_ eggTitle: String) -> Bool {
        // Piggybank is unlimited, never consume it
        if eggTitle == "Piggybank" {
            return true
        }
        
        guard let currentCount = gameData.purchasedEggs[eggTitle], currentCount > 0 else {
            return false
        }
        gameData.purchasedEggs[eggTitle] = currentCount - 1
        if gameData.purchasedEggs[eggTitle] == 0 {
            gameData.purchasedEggs.removeValue(forKey: eggTitle)
        }
        saveGameData()
        return true
    }
    
    func hasEgg(_ eggTitle: String) -> Bool {
        // Piggybank is unlimited, always available
        if eggTitle == "Piggybank" {
            return true
        }
        
        return (gameData.purchasedEggs[eggTitle] ?? 0) > 0
    }
    
    func getEgg(by title: String) -> Egg? {
        return ShopDatabase.default.shopItems.first(where: { $0.title == title })
    }
    
    // MARK: - Timer State
    
    /// Clears the saved background timestamp so a stale value doesn't
    /// corrupt the elapsed-time calculation on the next cold-launch restore.
    func clearSavedBackgroundTime() {
        gameData.savedBackgroundTime = nil
    }
    
    func saveTimerState(timeRemaining: TimeInterval, wasRunning: Bool, sessionStartTime: Date?, activeEggTitle: String?, isPiggybankMode: Bool, backgroundTime: Date? = nil, initialTimerDuration: TimeInterval? = nil) {
        gameData.savedTimeRemaining = timeRemaining
        // Only update session start time if it's a new session (nil means new session)
        if let startTime = sessionStartTime {
            gameData.savedSessionStartTime = startTime
        } else if gameData.savedSessionStartTime == nil {
            // New session - save current time
            gameData.savedSessionStartTime = Date()
        }
        // Otherwise, preserve existing session start time
        gameData.wasTimerRunning = wasRunning
        gameData.savedActiveEggTitle = activeEggTitle
        gameData.savedIsPiggybankMode = isPiggybankMode
        // Save background time if provided (for phone sleep scenario)
        if let bgTime = backgroundTime {
            gameData.savedBackgroundTime = bgTime
        }
        // Save initial timer duration for coin calculation (only update when provided)
        if let duration = initialTimerDuration {
            gameData.savedInitialTimerDuration = duration
        }
        saveGameData()
    }
    
    func restoreTimerState() -> (timeRemaining: TimeInterval, sessionStartTime: Date?, wasRunning: Bool, activeEggTitle: String?, isPiggybankMode: Bool, backgroundTime: Date?, initialTimerDuration: TimeInterval)? {
        guard gameData.wasTimerRunning, let startTime = gameData.savedSessionStartTime else {
            return nil
        }
        return (gameData.savedTimeRemaining, startTime, true, gameData.savedActiveEggTitle, gameData.savedIsPiggybankMode, gameData.savedBackgroundTime, gameData.savedInitialTimerDuration)
    }
    
    func clearTimerState() {
        gameData.savedTimeRemaining = 0
        gameData.savedSessionStartTime = nil
        gameData.wasTimerRunning = false
        gameData.savedActiveEggTitle = nil
        gameData.savedIsPiggybankMode = false
        gameData.savedBackgroundTime = nil
        gameData.savedInitialTimerDuration = 0
        saveGameData()
    }
    
    // MARK: - Break Management
    
    func startBreak(startTime: Date) {
        gameData.isOnBreak = true
        gameData.breakStartTime = startTime
        gameData.lastBreakTime = startTime
        saveGameData()
    }
    
    func endBreak() {
        gameData.isOnBreak = false
        gameData.breakStartTime = nil
        saveGameData()
    }
    
    func updateBreakTimeRemaining(_ timeRemaining: TimeInterval) {
        // Break state is already saved, just update if needed for restoration
        saveGameData()
    }
    
    func getLastBreakTime() -> Date? {
        return gameData.lastBreakTime
    }
    
    func restoreBreakState() -> (isOnBreak: Bool, timeRemaining: TimeInterval)? {
        guard gameData.isOnBreak, let breakStartTime = gameData.breakStartTime else {
            return nil
        }
        
        // Calculate remaining break time
        let elapsed = Date().timeIntervalSince(breakStartTime)
        let breakDuration: TimeInterval = 10 * 60 // 10 minutes
        let remaining = max(0, breakDuration - elapsed)
        
        return (true, remaining)
    }
    
    // MARK: - Study Time Tracking
    
    /// Adds completed session duration (seconds) to the lifetime total.
    func addStudyTime(_ duration: TimeInterval) {
        guard duration > 0 else { return }
        gameData.totalStudyTime += duration
        saveGameData()
        
        // Push updated stats to leaderboard
        Task {
            await LeaderboardManager.shared.pushStats()
        }
    }
    
    /// Returns total accumulated study time in seconds.
    func getTotalStudyTime() -> TimeInterval {
        return gameData.totalStudyTime
    }
    
    // MARK: - Hatch Statistics
    
    func recordHatching() {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let index = gameData.hatchCounts.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            gameData.hatchCounts[index].count += 1
        } else {
            gameData.hatchCounts.append(GameData.DailyHatchCount(date: today))
        }
        saveGameData()
        
        // Push updated stats to leaderboard
        Task {
            await LeaderboardManager.shared.pushStats()
        }
    }
    
    func getDailyHatchCount() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        return gameData.hatchCounts.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })?.count ?? 0
    }
    
    func getWeeklyHatchCount() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today)!
        return gameData.hatchCounts
            .filter { $0.date >= weekStart && $0.date <= today }
            .reduce(0) { $0 + $1.count }
    }
    
    func getMonthlyHatchCount() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monthStart = calendar.date(byAdding: .month, value: -1, to: today)!
        return gameData.hatchCounts
            .filter { $0.date >= monthStart && $0.date <= today }
            .reduce(0) { $0 + $1.count }
    }
    
    func getYearlyHatchCount() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yearStart = calendar.date(byAdding: .day, value: -364, to: today)!
        return gameData.hatchCounts
            .filter { $0.date >= yearStart && $0.date <= today }
            .reduce(0) { $0 + $1.count }
    }
    
    // MARK: - Shells
    
    func addShell(shellId: String, eggType: String, hatchDate: Date) {
        if !gameData.unlockedShells.contains(shellId) {
            gameData.unlockedShells.append(shellId)
            gameData.shellEggTypes[shellId] = eggType
            gameData.shellDates[shellId] = hatchDate
            saveGameData()
        }
    }
    
    func getShells() -> [(id: String, eggType: String, date: Date)] {
        return gameData.unlockedShells.compactMap { shellId in
            guard let eggType = gameData.shellEggTypes[shellId],
                  let date = gameData.shellDates[shellId] else {
                return nil
            }
            return (shellId, eggType, date)
        }
    }
    
    /// Removes a shell from all data stores (called after successful IAP).
    func removeShell(instanceId: String) {
        // Remove from grid instances
        gameData.animalInstances.removeAll { $0.id == instanceId && $0.isShell }
        
        // Remove from shell tracking arrays
        gameData.unlockedShells.removeAll { $0 == instanceId }
        gameData.shellEggTypes.removeValue(forKey: instanceId)
        gameData.shellDates.removeValue(forKey: instanceId)
        
        // Remove any stored positions
        gameData.originalPositions.removeValue(forKey: instanceId)
        for view in gameData.viewPositions.keys {
            gameData.viewPositions[view]?.removeValue(forKey: instanceId)
        }
        
        saveGameData()
        objectWillChange.send()
        print("🥚🗑️ GameDataManager: Removed shell \(instanceId)")
    }
    
    // MARK: - Grid Management
    
    func getAnimalInstances() -> [GameData.AnimalInstance] {
        return gameData.animalInstances
    }
    
    func getAnimalInstancesCount() -> Int {
        return gameData.animalInstances.count
    }
    
    func addAnimalInstance(_ instance: GameData.AnimalInstance) {
        gameData.animalInstances.append(instance)
        saveGameData()
    }
    
    func setOriginalPosition(_ id: String, position: GameData.GridPosition) {
        gameData.originalPositions[id] = position
        saveGameData()
    }
    
    func getOriginalPosition(_ id: String) -> GameData.GridPosition? {
        return gameData.originalPositions[id]
    }
    
    func getViewPositions(_ view: String) -> [String: GameData.GridPosition]? {
        return gameData.viewPositions[view]
    }
    
    func setViewPosition(_ view: String, id: String, position: GameData.GridPosition) {
        if gameData.viewPositions[view] == nil {
            gameData.viewPositions[view] = [:]
        }
        gameData.viewPositions[view]?[id] = position
        saveGameData()
    }
    
    func initializeViewPositions(_ view: String) {
        if gameData.viewPositions[view] == nil {
            gameData.viewPositions[view] = [:]
            saveGameData()
        }
    }
    
    func updateAnimalInstancePosition(_ id: String, position: GameData.GridPosition) {
        if let index = gameData.animalInstances.firstIndex(where: { $0.id == id }) {
            gameData.animalInstances[index].gridPosition = position
            saveGameData()
        }
    }
    
    func setGrassTileOffset(x: Double, y: Double) {
        gameData.grassTileOffset = GameData.TileOffset(x: x, y: y)
        saveGameData()
    }
    
    func setAnimalOffset(x: Double, y: Double) {
        gameData.animalOffset = GameData.TileOffset(x: x, y: y)
        saveGameData()
    }
    
    func getGrassTileOffset() -> GameData.TileOffset {
        return gameData.grassTileOffset
    }
    
    func getAnimalOffset() -> GameData.TileOffset {
        return gameData.animalOffset
    }
    
    func processPendingAnimal() {
        // Process all pending animals, not just one
        guard !gameData.pendingAnimals.isEmpty else { return }
        
        let eggType = gameData.currentSelectedEgg
        let isNewlyHatched = true
        
        // Process each pending animal with its actual hatch date
        for pendingAnimal in gameData.pendingAnimals {
            _ = GridManager.shared.placeAnimal(
                pendingAnimal.animalName,
                hatchDate: pendingAnimal.hatchDate,
                isNewlyHatched: isNewlyHatched,
                eggType: eggType
            )
        }
        
        // Clear all processed animals
        gameData.pendingAnimals.removeAll()
        saveGameData()
    }
    
    func processUnlockedShells() {
        for shellId in gameData.unlockedShells {
            if !gameData.animalInstances.contains(where: { $0.id == shellId && $0.isShell }) {
                if let eggType = gameData.shellEggTypes[shellId],
                   let hatchDate = gameData.shellDates[shellId] {
                    _ = GridManager.shared.placeShell(shellId: shellId, eggType: eggType, hatchDate: hatchDate)
                }
            }
        }
        saveGameData()
    }
    
    // MARK: - Study Streak
    
    /// Checks and updates the daily study streak. Publishes alert info if streak was updated.
    /// Pass `silent: true` to update streak data without showing an alert (e.g. when a result sheet is already presenting).
    func checkAndUpdateStreak(silent: Bool = false) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // If no previous streak day, start streak at 1
        guard let lastLogin = gameData.lastLoginDate else {
            gameData.lastLoginDate = today
            gameData.currentStreak = 1
            // Don't grant an extra egg on day 1 if the player already has starter eggs.
            if gameData.purchasedEggs.isEmpty {
                purchaseEgg("FarmEgg")
            }
            let reward = calculateStreakReward(streak: 1)
            // Don't grant extra day-1 coins if the player already has starter coins.
            let awardedCoins = (gameData.totalCoins == 0) ? reward : 0
            if awardedCoins > 0 {
                addCoins(awardedCoins)
            }
            saveGameData()
            objectWillChange.send() // Trigger view update
            if !silent {
                streakAlertInfo = (show: true, streak: 1, reward: awardedCoins, message: "Welcome! Your study streak has begun! 🎉")
            }
            return
        }
        
        let lastLoginDay = calendar.startOfDay(for: lastLogin)
        let daysSinceLastLogin = calendar.dateComponents([.day], from: lastLoginDay, to: today).day ?? 0
        
        // If already recorded a study session today, don't update
        if daysSinceLastLogin == 0 {
            if !silent {
                streakAlertInfo = nil
            }
            return
        }
        
        // If last study session was yesterday, continue streak
        if daysSinceLastLogin == 1 {
            gameData.currentStreak += 1
            gameData.lastLoginDate = today
            let reward = calculateStreakReward(streak: gameData.currentStreak)
            addCoins(reward)
            // Grant milestone egg if applicable
            let milestoneReward = getPotentialReward(for: gameData.currentStreak)
            if let egg = milestoneReward.egg {
                purchaseEgg(egg)
            }
            saveGameData()
            objectWillChange.send() // Trigger view update
            if !silent {
                let eggNote = milestoneReward.egg != nil ? "\nBonus: Free \(milestoneReward.egg!) 🥚" : ""
                streakAlertInfo = (show: true, streak: gameData.currentStreak, reward: reward, message: "Day \(gameData.currentStreak) of your study streak! 🔥\(eggNote)")
            }
            return
        }
        
        // If more than 1 day, reset streak
        gameData.currentStreak = 1
        gameData.lastLoginDate = today
        // Give FarmEgg when streak resets
        purchaseEgg("FarmEgg")
        let reward = calculateStreakReward(streak: 1)
        addCoins(reward)
        saveGameData()
        objectWillChange.send() // Trigger view update
        if !silent {
            streakAlertInfo = (show: true, streak: 1, reward: reward, message: "Your streak was broken, but you're back! Starting fresh! 💪")
        }
    }
    
    func dismissStreakAlert() {
        streakAlertInfo = nil
    }
    
    /// Calculates the reward coins based on streak length.
    /// Flat daily coins with big milestone bonuses at days 3, 7, 14 and 30.
    private func calculateStreakReward(streak: Int) -> Int {
        // Day 1 welcome reward
        if streak == 1 { return 100 }

        // Base: 25 coins every day
        var reward = 25

        // Milestone bonuses (exact-day hits)
        switch streak {
        case 3:  reward += 75   // Day 3 milestone
        case 7:  reward += 150  // Week milestone
        case 14: reward += 300  // Two-week milestone
        case 30: reward += 500  // Month milestone
        default: break
        }

        // Ongoing scaling: +5 coins for every full week in the streak
        reward += (streak / 7) * 5

        return reward
    }
    
    func getCurrentStreak() -> Int {
        return gameData.currentStreak
    }
    
    func getLastLoginDate() -> Date? {
        return gameData.lastLoginDate
    }
    
    /// Gets the potential reward for a given streak day.
    /// Milestone days award a free egg alongside coins.
    func getPotentialReward(for streak: Int) -> (coins: Int, egg: String?) {
        let coins = calculateStreakReward(streak: streak)
        let egg: String?
        switch streak {
        case 1:  egg = "FarmEgg"
        case 3:  egg = "FarmEgg"
        case 7:  egg = "JungleEgg"
        case 14: egg = "JungleEgg"
        case 30: egg = "ArticEgg"
        default: egg = nil
        }
        return (coins, egg)
    }
    
    // MARK: - Debug
    

}

