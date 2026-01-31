//
//  GameData.swift
//  Fauna
//
//  Replaces: PlayerPrefs data storage
//

import Foundation

struct GameData: Codable {
    var totalCoins: Int = 0
    var unlockedAnimals: [String] = [] // Animal names
    var purchasedEggs: [String: Int] = [:] // Egg title: quantity
    var currentSelectedEgg: String? = nil
    /// When multiple of same egg: which instance is selected (e.g. "FarmEgg-1"). Nil = any instance.
    var currentSelectedEggInstanceId: String? = nil
    var pendingAnimals: [PendingAnimal] = [] // Newly hatched animals waiting to be placed
    
    struct PendingAnimal: Codable {
        let animalName: String
        let hatchDate: Date
    }
    
    // Timer state
    var savedTimeRemaining: TimeInterval = 0
    var savedSessionStartTime: Date? = nil
    var wasTimerRunning: Bool = false
    var savedActiveEggTitle: String? = nil
    var savedIsPiggybankMode: Bool = false
    var savedBackgroundTime: Date? = nil // When app went to background (for phone sleep)
    
    // Break tracking
    var lastBreakTime: Date? = nil
    var isOnBreak: Bool = false
    var breakStartTime: Date? = nil
    
    // Hatch statistics (replaces HatchData)
    var hatchCounts: [DailyHatchCount] = []
    
    // Login streak tracking
    var lastLoginDate: Date? = nil
    var currentStreak: Int = 0
    
    // Graves (replaces UnlockedGraves)
    var unlockedGraves: [String] = [] // Grave IDs
    var graveEggTypes: [String: String] = [:] // Grave ID: Egg Type
    var graveDates: [String: Date] = [:] // Grave ID: Hatch Date
    
    // Grid positions for animals and graves
    var animalInstances: [AnimalInstance] = []
    var originalPositions: [String: GridPosition] = [:] // For "All" view restoration
    var viewPositions: [String: [String: GridPosition]] = [:] // View-specific positions
    
    // Isometric grid customization
    // EDIT THESE VALUES TO ADJUST POSITIONING:
    // - grassTileOffset: Move grass tiles (x, y in pixels)
    // - animalOffset: Move animals relative to tiles (x, y in pixels)
    var grassTileOffset: TileOffset = TileOffset(x: 0, y: 0) // Offset for grass tiles
    var animalOffset: TileOffset = TileOffset(x: 0, y: -10) // Offset for animals (typically above tile)
    
    struct TileOffset: Codable {
        var x: Double
        var y: Double
    }
    
    struct DailyHatchCount: Codable {
        let date: Date
        var count: Int
        
        init(date: Date, count: Int = 1) {
            self.date = date
            self.count = count
        }
    }
    
    struct AnimalInstance: Codable {
        let id: String
        let animalName: String
        var gridPosition: GridPosition
        let hatchDate: Date
        var isNewlyHatched: Bool
        let isGrave: Bool
        let eggType: String?
    }
    
    struct GridPosition: Codable, Hashable {
        let x: Int
        let y: Int
        
        init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
        
        static func == (lhs: GridPosition, rhs: GridPosition) -> Bool {
            return lhs.x == rhs.x && lhs.y == rhs.y
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(x)
            hasher.combine(y)
        }
    }
}

