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
    let isGrave: Bool
    let eggType: String? // "FarmEgg", "JungleEgg", etc.
    
    init(name: String, imageName: String, eggType: String? = nil) {
        self.id = UUID().uuidString
        self.name = name
        self.imageName = imageName
        self.hatchDate = Date()
        self.isNewlyHatched = true
        self.isGrave = false
        self.eggType = eggType
    }
    
    // For graves
    init(graveId: String, eggType: String, hatchDate: Date) {
        self.id = graveId
        self.name = "Grave"
        self.imageName = "grave"
        self.hatchDate = hatchDate
        self.isNewlyHatched = false
        self.isGrave = true
        self.eggType = eggType
    }
}

// Helper for animal spawn chances (replaces ShopItemSO.AnimalSpawnChance)
struct AnimalSpawnChance: Codable {
    let animalName: String
    let spawnChance: Double // 0.0 to 100.0
}

