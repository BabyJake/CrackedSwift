//
//  GameData.swift
//  Fauna
//
//  Replaces: PlayerPrefs data storage
//
//  IMPORTANT: Every property uses a resilient custom decoder so that adding,
//  renaming, or changing fields between builds will NOT wipe user data.
//  Each key is decoded individually with a fallback default.
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
    
    // Timer state
    var savedTimeRemaining: TimeInterval = 0
    var savedSessionStartTime: Date? = nil
    var wasTimerRunning: Bool = false
    var savedActiveEggTitle: String? = nil
    var savedIsPiggybankMode: Bool = false
    var savedBackgroundTime: Date? = nil // When app went to background (for phone sleep)
    var savedInitialTimerDuration: TimeInterval = 0 // Original timer duration for coin calculation
    
    // Break tracking
    var lastBreakTime: Date? = nil
    var isOnBreak: Bool = false
    var breakStartTime: Date? = nil
    
    // Hatch statistics (replaces HatchData)
    var hatchCounts: [DailyHatchCount] = []
    
    // Login streak tracking
    var lastLoginDate: Date? = nil
    var currentStreak: Int = 0
    
    // Shells (cracked eggs)
    var unlockedShells: [String] = [] // Shell IDs
    var shellEggTypes: [String: String] = [:] // Shell ID: Egg Type
    var shellDates: [String: Date] = [:] // Shell ID: Date
    
    // Total actual study time (seconds) accumulated from successful sessions
    var totalStudyTime: TimeInterval = 0
    
    // Grid positions for animals and shells
    var animalInstances: [AnimalInstance] = []
    var originalPositions: [String: GridPosition] = [:] // For "All" view restoration
    var viewPositions: [String: [String: GridPosition]] = [:] // View-specific positions
    
    // Isometric grid customization
    // EDIT THESE VALUES TO ADJUST POSITIONING:
    // - grassTileOffset: Move grass tiles (x, y in pixels)
    // - animalOffset: Move animals relative to tiles (x, y in pixels)
    var grassTileOffset: TileOffset = TileOffset(x: 0, y: 0) // Offset for grass tiles
    var animalOffset: TileOffset = TileOffset(x: 0, y: 0) // Offset for animals relative to tile center (positive = down)
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case totalCoins
        case unlockedAnimals
        case purchasedEggs
        case currentSelectedEgg
        case currentSelectedEggInstanceId
        case pendingAnimals
        case savedTimeRemaining
        case savedSessionStartTime
        case wasTimerRunning
        case savedActiveEggTitle
        case savedIsPiggybankMode
        case savedBackgroundTime
        case savedInitialTimerDuration
        case lastBreakTime
        case isOnBreak
        case breakStartTime
        case hatchCounts
        case lastLoginDate
        case currentStreak
        case unlockedShells = "unlockedGraves"
        case shellEggTypes = "graveEggTypes"
        case shellDates = "graveDates"
        case totalStudyTime
        case animalInstances
        case originalPositions
        case viewPositions
        case grassTileOffset
        case animalOffset
    }
    
    // MARK: - Resilient Decoder
    // Each property decoded individually so a missing/changed key never nukes the whole save.
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        
        totalCoins              = (try? c.decode(Int.self, forKey: .totalCoins)) ?? 0
        unlockedAnimals         = (try? c.decode([String].self, forKey: .unlockedAnimals)) ?? []
        purchasedEggs           = (try? c.decode([String: Int].self, forKey: .purchasedEggs)) ?? [:]
        currentSelectedEgg      = try? c.decode(String.self, forKey: .currentSelectedEgg)
        currentSelectedEggInstanceId = try? c.decode(String.self, forKey: .currentSelectedEggInstanceId)
        pendingAnimals          = (try? c.decode([PendingAnimal].self, forKey: .pendingAnimals)) ?? []
        
        savedTimeRemaining      = (try? c.decode(TimeInterval.self, forKey: .savedTimeRemaining)) ?? 0
        savedSessionStartTime   = try? c.decode(Date.self, forKey: .savedSessionStartTime)
        wasTimerRunning         = (try? c.decode(Bool.self, forKey: .wasTimerRunning)) ?? false
        savedActiveEggTitle     = try? c.decode(String.self, forKey: .savedActiveEggTitle)
        savedIsPiggybankMode    = (try? c.decode(Bool.self, forKey: .savedIsPiggybankMode)) ?? false
        savedBackgroundTime     = try? c.decode(Date.self, forKey: .savedBackgroundTime)
        savedInitialTimerDuration = (try? c.decode(TimeInterval.self, forKey: .savedInitialTimerDuration)) ?? 0
        
        lastBreakTime           = try? c.decode(Date.self, forKey: .lastBreakTime)
        isOnBreak               = (try? c.decode(Bool.self, forKey: .isOnBreak)) ?? false
        breakStartTime          = try? c.decode(Date.self, forKey: .breakStartTime)
        
        hatchCounts             = (try? c.decode([DailyHatchCount].self, forKey: .hatchCounts)) ?? []
        
        lastLoginDate           = try? c.decode(Date.self, forKey: .lastLoginDate)
        currentStreak           = (try? c.decode(Int.self, forKey: .currentStreak)) ?? 0
        
        unlockedShells          = (try? c.decode([String].self, forKey: .unlockedShells)) ?? []
        shellEggTypes           = (try? c.decode([String: String].self, forKey: .shellEggTypes)) ?? [:]
        shellDates              = (try? c.decode([String: Date].self, forKey: .shellDates)) ?? [:]
        
        totalStudyTime          = (try? c.decode(TimeInterval.self, forKey: .totalStudyTime)) ?? 0
        animalInstances         = (try? c.decode([AnimalInstance].self, forKey: .animalInstances)) ?? []
        originalPositions       = (try? c.decode([String: GridPosition].self, forKey: .originalPositions)) ?? [:]
        viewPositions           = (try? c.decode([String: [String: GridPosition]].self, forKey: .viewPositions)) ?? [:]
        
        grassTileOffset         = (try? c.decode(TileOffset.self, forKey: .grassTileOffset)) ?? TileOffset(x: 0, y: 0)
        animalOffset            = (try? c.decode(TileOffset.self, forKey: .animalOffset)) ?? TileOffset(x: 0, y: 0)
    }
    
    // MARK: - Default memberwise init (used when creating fresh GameData)
    
    init() {}
    
    // MARK: - Nested Types
    
    struct PendingAnimal: Codable {
        let animalName: String
        let hatchDate: Date
        
        enum CodingKeys: String, CodingKey {
            case animalName
            case hatchDate
        }
        
        init(animalName: String, hatchDate: Date) {
            self.animalName = animalName
            self.hatchDate = hatchDate
        }
        
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            animalName = (try? c.decode(String.self, forKey: .animalName)) ?? "Unknown"
            hatchDate  = (try? c.decode(Date.self, forKey: .hatchDate)) ?? Date()
        }
    }
    
    struct TileOffset: Codable {
        var x: Double
        var y: Double
        
        enum CodingKeys: String, CodingKey {
            case x, y
        }
        
        init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
        
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            x = (try? c.decode(Double.self, forKey: .x)) ?? 0
            y = (try? c.decode(Double.self, forKey: .y)) ?? 0
        }
    }
    
    struct DailyHatchCount: Codable {
        let date: Date
        var count: Int
        
        enum CodingKeys: String, CodingKey {
            case date, count
        }
        
        init(date: Date, count: Int = 1) {
            self.date = date
            self.count = count
        }
        
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            date  = (try? c.decode(Date.self, forKey: .date)) ?? Date()
            count = (try? c.decode(Int.self, forKey: .count)) ?? 1
        }
    }
    
    struct AnimalInstance: Codable, Identifiable {
        let id: String
        let animalName: String
        var gridPosition: GridPosition
        let hatchDate: Date
        var isNewlyHatched: Bool
        let isShell: Bool
        let eggType: String?
        
        enum CodingKeys: String, CodingKey {
            case id, animalName, gridPosition, hatchDate, isNewlyHatched
            case isShell = "isGrave"
            case eggType
        }
        
        init(id: String, animalName: String, gridPosition: GridPosition, hatchDate: Date, isNewlyHatched: Bool, isShell: Bool, eggType: String?) {
            self.id = id
            self.animalName = animalName
            self.gridPosition = gridPosition
            self.hatchDate = hatchDate
            self.isNewlyHatched = isNewlyHatched
            self.isShell = isShell
            self.eggType = eggType
        }
        
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id            = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
            animalName    = (try? c.decode(String.self, forKey: .animalName)) ?? "Unknown"
            gridPosition  = (try? c.decode(GridPosition.self, forKey: .gridPosition)) ?? GridPosition(x: 0, y: 0)
            hatchDate     = (try? c.decode(Date.self, forKey: .hatchDate)) ?? Date()
            isNewlyHatched = (try? c.decode(Bool.self, forKey: .isNewlyHatched)) ?? false
            isShell       = (try? c.decode(Bool.self, forKey: .isShell)) ?? false
            eggType       = try? c.decode(String.self, forKey: .eggType)
        }
    }
    
    struct GridPosition: Codable, Hashable {
        let x: Int
        let y: Int
        
        enum CodingKeys: String, CodingKey {
            case x, y
        }
        
        init(x: Int, y: Int) {
            self.x = x
            self.y = y
        }
        
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            x = (try? c.decode(Int.self, forKey: .x)) ?? 0
            y = (try? c.decode(Int.self, forKey: .y)) ?? 0
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

