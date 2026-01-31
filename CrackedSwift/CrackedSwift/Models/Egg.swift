//
//  Egg.swift
//  Fauna
//
//  Replaces: ShopItemSO.cs (for egg types)
//

import Foundation

struct Egg: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let baseCost: Int
    let imageName: String
    let animalSpawnChances: [AnimalSpawnChance]
    
    init(title: String, description: String, baseCost: Int, imageName: String, spawnChances: [AnimalSpawnChance] = []) {
        self.id = title
        self.title = title
        self.description = description
        self.baseCost = baseCost
        self.imageName = imageName
        self.animalSpawnChances = spawnChances
    }
}

// Shop Database (replaces ShopDatabase.cs)
struct ShopDatabase: Codable {
    let shopItems: [Egg]
    
    static let `default` = ShopDatabase(shopItems: [
        Egg(
            title: "FarmEgg",
            description: "A farm egg with farm animals",
            baseCost: 100,
            imageName: "FarmEgg",
            spawnChances: [
                // Common (40% total - 10.0% each)
                AnimalSpawnChance(animalName: "Chicken", spawnChance: 10.0),
                AnimalSpawnChance(animalName: "Duck", spawnChance: 10.0),
                AnimalSpawnChance(animalName: "Mouse", spawnChance: 10.0),
                AnimalSpawnChance(animalName: "Rabbit", spawnChance: 10.0),
                // Uncommon (25% total - 8.33% each)
                AnimalSpawnChance(animalName: "Goat", spawnChance: 8.33),
                AnimalSpawnChance(animalName: "Pig", spawnChance: 8.33),
                AnimalSpawnChance(animalName: "Sheep", spawnChance: 8.34),
                // Rare (20% total - 6.67% each)
                AnimalSpawnChance(animalName: "BorderCollie", spawnChance: 6.67),
                AnimalSpawnChance(animalName: "Cow", spawnChance: 6.67),
                AnimalSpawnChance(animalName: "Turkey", spawnChance: 6.66),
                // Epic (10% total - 5.0% each)
                AnimalSpawnChance(animalName: "Horse", spawnChance: 5.0),
                AnimalSpawnChance(animalName: "Donkey", spawnChance: 5.0),
                // Legendary (4% total - 2.0% each)
                AnimalSpawnChance(animalName: "Scarecrow", spawnChance: 2.0),
                AnimalSpawnChance(animalName: "Unicorn", spawnChance: 2.0),
                // Mythic (0.5% total)
                AnimalSpawnChance(animalName: "GoldenGoose", spawnChance: 0.5)
            ]
        ),
        Egg(
            title: "JungleEgg",
            description: "A jungle egg with exotic animals",
            baseCost: 250,
            imageName: "JungleEgg",
            spawnChances: [
                // Common (40% total - 10.0% each)
                AnimalSpawnChance(animalName: "Frog", spawnChance: 10.0),
                AnimalSpawnChance(animalName: "Parrot", spawnChance: 10.0),
                AnimalSpawnChance(animalName: "Monkey", spawnChance: 10.0),
                AnimalSpawnChance(animalName: "Snake", spawnChance: 10.0),
                // Uncommon (25% total - 5.0% each)
                AnimalSpawnChance(animalName: "Lemur", spawnChance: 5.0),
                AnimalSpawnChance(animalName: "Koala", spawnChance: 5.0),
                AnimalSpawnChance(animalName: "Chameleon", spawnChance: 5.0),
                AnimalSpawnChance(animalName: "Toucan", spawnChance: 5.0),
                AnimalSpawnChance(animalName: "JungleElephant", spawnChance: 5.0),
                // Rare (20% total - 6.67% each)
                AnimalSpawnChance(animalName: "Panda", spawnChance: 6.67),
                AnimalSpawnChance(animalName: "Caiman", spawnChance: 6.67),
                AnimalSpawnChance(animalName: "Capybara", spawnChance: 6.66),
                // Epic (10% total - 5.0% each)
                AnimalSpawnChance(animalName: "Jaguar", spawnChance: 5.0),
                AnimalSpawnChance(animalName: "Sloth", spawnChance: 5.0),
                // Legendary (4% total - 2.0% each)
                AnimalSpawnChance(animalName: "Gorilla", spawnChance: 2.0),
                AnimalSpawnChance(animalName: "Tiger", spawnChance: 2.0),
                // Mythic (0.5% total)
                AnimalSpawnChance(animalName: "SunGod", spawnChance: 0.5)
            ]
        ),
        Egg(
            title: "ArticEgg",
            description: "An arctic egg with cold-weather animals",
            baseCost: 500,
            imageName: "ArticEgg",
            spawnChances: [
                // Common (40% total - 10.0% each)
                AnimalSpawnChance(animalName: "ArticFox", spawnChance: 10.0),
                AnimalSpawnChance(animalName: "ArticHare", spawnChance: 10.0),
                AnimalSpawnChance(animalName: "Seal", spawnChance: 10.0),
                AnimalSpawnChance(animalName: "walrus", spawnChance: 10.0),
                // Uncommon (25% total - 8.33% each)
                AnimalSpawnChance(animalName: "ArticLemming", spawnChance: 8.33),
                AnimalSpawnChance(animalName: "DallSheep", spawnChance: 8.33),
                AnimalSpawnChance(animalName: "ArcticPenguin", spawnChance: 8.34),
                // Rare (20% total - 6.67% each)
                AnimalSpawnChance(animalName: "Ermine", spawnChance: 6.67),
                AnimalSpawnChance(animalName: "Husky", spawnChance: 6.67),
                AnimalSpawnChance(animalName: "MuskOx", spawnChance: 6.66),
                // Epic (10% total - 5.0% each)
                AnimalSpawnChance(animalName: "Lynx", spawnChance: 5.0),
                AnimalSpawnChance(animalName: "SnowLeopard", spawnChance: 5.0),
                // Legendary (4% total - 2.0% each)
                AnimalSpawnChance(animalName: "PolarBear", spawnChance: 2.0),
                AnimalSpawnChance(animalName: "Rudolph", spawnChance: 2.0),
                // Mythic (0.5% total)
                AnimalSpawnChance(animalName: "Yeti", spawnChance: 0.5)
            ]
        )
        // Add more eggs as needed
        // Note: Animal names must match names in AnimalDatabase.swift
    ])
}

