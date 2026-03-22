//
//  Animal.swift
//  Fauna
//
//  Replaces: Unity's animal prefab system
//

import Foundation

struct Animal: Identifiable, Codable {
    let id: String
    let name: String
    let imageName: String // Name of asset in Assets.xcassets
    let hatchDate: Date
    let isNewlyHatched: Bool
    let isShell: Bool
    let eggType: String? // "FarmEgg", "JungleEgg", etc.
    
    init(name: String, imageName: String, eggType: String? = nil) {
        self.id = UUID().uuidString
        self.name = name
        self.imageName = imageName
        self.hatchDate = Date()
        self.isNewlyHatched = true
        self.isShell = false
        self.eggType = eggType
    }
    
    // For shells (cracked eggs)
    init(shellId: String, eggType: String, hatchDate: Date) {
        self.id = shellId
        self.name = "Shell"
        self.imageName = "shell"
        self.hatchDate = hatchDate
        self.isNewlyHatched = false
        self.isShell = true
        self.eggType = eggType
    }
}

// Helper for animal spawn chances (replaces ShopItemSO.AnimalSpawnChance)
struct AnimalSpawnChance: Codable {
    let animalName: String
    let spawnChance: Double // 0.0 to 100.0
}

