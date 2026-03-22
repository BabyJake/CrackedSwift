//
//  AnimalManager.swift
//  Fauna
//
//  Replaces: Animal spawning and hatching logic from StudyTimer.cs
//

import Foundation

/// Rarity tier spawn percentage for display purposes (e.g. rarity ring)
struct RarityTierChance: Equatable {
    let rarity: AnimalRarity
    let percentage: Double // 0.0 to 1.0
}

@MainActor
final class AnimalManager: ObservableObject {
    static let shared = AnimalManager()
    
    private let dataManager = GameDataManager.shared
    private let shopManager = ShopManager.shared
    
    private init() {}
    
    // MARK: - Hatching
    
    func hatchEgg(studyDuration: TimeInterval = 0) -> Animal? {
        let currentEggTitle = dataManager.getCurrentEgg() ?? "FarmEgg"
        guard let egg = shopManager.getEggByTitle(currentEggTitle) else {
            // Fallback to random animal if no egg selected
            return createRandomAnimal(eggType: "FarmEgg")
        }
        
        // Use egg's spawn chances to determine animal (with duration-based rarity boost)
        let selectedAnimalName = selectAnimalFromEgg(egg, studyDuration: studyDuration)
        
        // Get image name from AnimalDatabase (or use fallback)
        let imageName = AnimalDatabase.getImageName(for: selectedAnimalName)
        
        // Create animal with proper image name
        let animal = Animal(name: selectedAnimalName, imageName: imageName, eggType: currentEggTitle)
        
        // Unlock animal
        dataManager.addUnlockedAnimal(selectedAnimalName)
        dataManager.setPendingAnimal(selectedAnimalName)
        
        // Record hatching
        dataManager.recordHatching()
        
        return animal
    }
    
    private func selectAnimalFromEgg(_ egg: Egg, studyDuration: TimeInterval) -> String {
        // If spawn chances are defined, use weighted random with duration-based rarity boost
        if !egg.animalSpawnChances.isEmpty {
            // Calculate rarity boost based on study duration (in minutes)
            let studyMinutes = studyDuration / 60.0
            let adjustedChances = adjustSpawnChancesForDuration(egg.animalSpawnChances, studyMinutes: studyMinutes)
            
            let totalChance = adjustedChances.reduce(0.0) { $0 + $1.spawnChance }
            let random = Double.random(in: 0..<totalChance)
            
            var accumulated = 0.0
            for chance in adjustedChances {
                accumulated += chance.spawnChance
                if random <= accumulated {
                    return chance.animalName
                }
            }
        }
        
        // Fallback: return first animal name from spawn chances, or default
        return egg.animalSpawnChances.first?.animalName ?? "DefaultAnimal"
    }
    
    /// Adjusts spawn chances based on study duration to boost rare animals
    /// Normalizes spawn rates so all animals within the same rarity tier have equal chances
    /// - Parameters:
    ///   - chances: Original spawn chances
    ///   - studyMinutes: Study duration in minutes
    /// - Returns: Adjusted spawn chances with normalized rates and rarity boosts applied
    private func adjustSpawnChancesForDuration(_ chances: [AnimalSpawnChance], studyMinutes: Double) -> [AnimalSpawnChance] {
        // Calculate boost multipliers based on study duration (nerfed to reduce rare animal spawns)
        // Short study (0-15 min): no boost
        // Medium study (15-30 min): +3% rare, +2% epic, +1% legendary
        // Long study (30-60 min): +6% rare, +4% epic, +2% legendary
        // Very long study (60+ min): +10% rare, +8% epic, +5% legendary
        
        var uncommonBoost: Double = 0.0
        var rareBoost: Double = 0.0
        var epicBoost: Double = 0.0
        var legendaryBoost: Double = 0.0
        var mythicBoost: Double = 0.0
        
        // Progressive boosts: longer sessions give a small edge on rarer spawns
        // Kept conservative so mythics/legendaries stay genuinely rare
        if studyMinutes >= 90 {
            uncommonBoost = 0.18
            rareBoost = 0.22
            epicBoost = 0.16
            legendaryBoost = 0.10
            mythicBoost = 0.04
        } else if studyMinutes >= 60 {
            uncommonBoost = 0.14
            rareBoost = 0.18
            epicBoost = 0.12
            legendaryBoost = 0.07
            mythicBoost = 0.025
        } else if studyMinutes >= 45 {
            uncommonBoost = 0.11
            rareBoost = 0.14
            epicBoost = 0.09
            legendaryBoost = 0.05
            mythicBoost = 0.015
        } else if studyMinutes >= 30 {
            uncommonBoost = 0.08
            rareBoost = 0.10
            epicBoost = 0.06
            legendaryBoost = 0.03
            mythicBoost = 0.008
        } else if studyMinutes >= 20 {
            uncommonBoost = 0.05
            rareBoost = 0.06
            epicBoost = 0.03
            legendaryBoost = 0.015
            mythicBoost = 0.004
        } else if studyMinutes >= 10 {
            uncommonBoost = 0.03
            rareBoost = 0.03
            epicBoost = 0.015
            legendaryBoost = 0.008
            mythicBoost = 0.002
        }
        
        // First pass: Group animals by rarity and calculate total spawn chance per tier
        var rarityTotals: [AnimalRarity: Double] = [:]
        var rarityCounts: [AnimalRarity: Int] = [:]
        
        for chance in chances {
            guard let animalData = AnimalDatabase.getAnimalData(for: chance.animalName) else {
                continue
            }
            
            let rarity = animalData.rarity
            rarityTotals[rarity, default: 0.0] += chance.spawnChance
            rarityCounts[rarity, default: 0] += 1
        }
        
        // Second pass: Normalize spawn chances - distribute total equally among animals in each tier
        var normalizedChances: [AnimalSpawnChance] = []
        
        for chance in chances {
            guard let animalData = AnimalDatabase.getAnimalData(for: chance.animalName) else {
                normalizedChances.append(chance)
                continue
            }
            
            let rarity = animalData.rarity
            let totalForRarity = rarityTotals[rarity] ?? 0.0
            let countForRarity = rarityCounts[rarity] ?? 1
            
            // Normalize: each animal in the same rarity tier gets equal spawn chance
            let normalizedChance = countForRarity > 0 ? totalForRarity / Double(countForRarity) : chance.spawnChance
            
            // Apply duration-based boosts
            var adjustedChance = normalizedChance
            
            switch rarity {
            case .rare:
                adjustedChance = normalizedChance * (1.0 + rareBoost)
            case .epic:
                adjustedChance = normalizedChance * (1.0 + epicBoost)
            case .legendary:
                adjustedChance = normalizedChance * (1.0 + legendaryBoost)
            case .mythic:
                adjustedChance = normalizedChance * (1.0 + mythicBoost)
            case .uncommon:
                adjustedChance = normalizedChance * (1.0 + uncommonBoost)
            case .common:
                // Reduce common animals proportionally to make room for boosted rarities
                let reductionFactor = 1.0 - (uncommonBoost * 0.15 + rareBoost * 0.25 + epicBoost * 0.2 + legendaryBoost * 0.1 + mythicBoost * 0.05)
                adjustedChance = normalizedChance * max(0.1, reductionFactor) // Keep at least 10% of original
            }
            
            normalizedChances.append(AnimalSpawnChance(animalName: chance.animalName, spawnChance: adjustedChance))
        }
        
        return normalizedChances
    }
    
    private func createRandomAnimal(eggType: String) -> Animal {
        // Get common animals as fallback
        let commonAnimals = AnimalDatabase.getAnimalsByRarity(.common)
        let animalData = commonAnimals.randomElement() ?? AnimalData(
            name: "DefaultAnimal",
            imageName: "default_animal",
            rarity: .common,
            description: nil
        )
        
        let animal = Animal(name: animalData.name, imageName: animalData.imageName, eggType: eggType)
        dataManager.addUnlockedAnimal(animalData.name)
        dataManager.setPendingAnimal(animalData.name)
        dataManager.recordHatching()
        
        return animal
    }
    
    // MARK: - Animal Data Helpers
    
    func getAnimalData(for name: String) -> AnimalData? {
        return AnimalDatabase.getAnimalData(for: name)
    }
    
    func getImageName(for animalName: String) -> String {
        return AnimalDatabase.getImageName(for: animalName)
    }
    
    // MARK: - Shells
    
    func createShell(for eggType: String) -> Animal {
        let shellId = "Shell_\(Date().timeIntervalSince1970)"
        let shellDate = Date()
        
        dataManager.addShell(shellId: shellId, eggType: eggType, hatchDate: shellDate)
        
        return Animal(shellId: shellId, eggType: eggType, hatchDate: shellDate)
    }
    
    // MARK: - Rarity Distribution
    
    /// Returns the rarity tier distribution for a given egg and study duration.
    /// Used by RarityRingView to visualize spawn chances.
    func getRarityDistribution(eggTitle: String, studyMinutes: Double) -> [RarityTierChance] {
        guard let egg = shopManager.getEggByTitle(eggTitle) else { return [] }
        
        let adjustedChances = adjustSpawnChancesForDuration(egg.animalSpawnChances, studyMinutes: studyMinutes)
        let total = adjustedChances.reduce(0.0) { $0 + $1.spawnChance }
        guard total > 0 else { return [] }
        
        // Sum spawn chances by rarity tier
        var rarityTotals: [AnimalRarity: Double] = [:]
        for chance in adjustedChances {
            if let animalData = AnimalDatabase.getAnimalData(for: chance.animalName) {
                rarityTotals[animalData.rarity, default: 0] += chance.spawnChance
            }
        }
        
        // Build ordered result — always include all 6 rarities for smooth animation
        let order: [AnimalRarity] = [.common, .uncommon, .rare, .epic, .legendary, .mythic]
        return order.map { rarity in
            RarityTierChance(rarity: rarity, percentage: (rarityTotals[rarity] ?? 0) / total)
        }
    }
    
    // MARK: - Unlocked Animals
    
    func getUnlockedAnimals() -> [String] {
        return dataManager.getUnlockedAnimals()
    }
}

