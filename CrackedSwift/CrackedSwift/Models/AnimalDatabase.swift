//
//  AnimalDatabase.swift
//  CrackedSwift
//
//  Easy-to-use database for adding animals and their images
//

import Foundation

struct AnimalData {
    let name: String
    let imageName: String  // Name of image in Assets.xcassets
    let rarity: AnimalRarity
    let description: String?
}

enum AnimalRarity: String, Codable {
    case common
    case uncommon
    case rare
    case epic
    case legendary
    case mythic
}

struct AnimalDatabase {
    // MARK: - Easy Animal Definitions
    // Add new animals here - just copy the format and add your animal!
    
    static let animals: [String: AnimalData] = [
        // Common Animals
        "Cat": AnimalData(
            name: "Cat",
            imageName: "Cat",
            rarity: .common,
            description: "A cute little cat"
        ),
        "Elephant": AnimalData(
            name: "Elephant",
            imageName: "Elephant",
            rarity: .common,
            description: "A majestic elephant"
        ),
        "Lion": AnimalData(
            name: "Lion",
            imageName: "Lion",
            rarity: .common,
            description: "A powerful lion"
        ),
        "Orangutan": AnimalData(
            name: "Orangutan",
            imageName: "Orangutan",
            rarity: .common,
            description: "A clever orangutan"
        ),
        "Tiger": AnimalData(
            name: "Tiger",
            imageName: "Legendary_Tiger",
            rarity: .legendary,
            description: "A legendary jungle tiger"
        ),
        "Penguin": AnimalData(
            name: "Penguin",
            imageName: "Penguin",
            rarity: .common,
            description: "A cute fluffy penguin"
        ),
        "Bat": AnimalData(
            name: "Bat",
            imageName: "Bat",
            rarity: .common,
            description: "A flying bat"
        ),
        "Crocodile": AnimalData(
            name: "Crocodile",
            imageName: "Crocodile",
            rarity: .common,
            description: "A fierce crocodile"
        ),
        "Dog": AnimalData(
            name: "Dog",
            imageName: "Dog",
            rarity: .common,
            description: "A loyal dog"
        ),
        "Donkey": AnimalData(
            name: "Donkey",
            imageName: "Donkey_Epic",
            rarity: .epic,
            description: "An epic hardworking donkey"
        ),
        "Giraffe": AnimalData(
            name: "Giraffe",
            imageName: "Giraffe",
            rarity: .common,
            description: "A tall giraffe"
        ),
        "Hippo": AnimalData(
            name: "Hippo",
            imageName: "Hippo",
            rarity: .common,
            description: "A massive hippo"
        ),
        "Monkey": AnimalData(
            name: "Monkey",
            imageName: "Common_Monkey",
            rarity: .common,
            description: "A playful jungle monkey"
        ),
        "Panda": AnimalData(
            name: "Panda",
            imageName: "Rare_Panda",
            rarity: .rare,
            description: "A rare jungle panda"
        ),
        "polarbear": AnimalData(
            name: "polarbear",
            imageName: "Legendary_PolarBear",
            rarity: .legendary,
            description: "A legendary arctic polar bear"
        ),
        "Rhino": AnimalData(
            name: "Rhino",
            imageName: "Rhino",
            rarity: .common,
            description: "A powerful rhino"
        ),
        "Turtle": AnimalData(
            name: "Turtle",
            imageName: "Turtle",
            rarity: .common,
            description: "A slow turtle"
        ),
        "Zebra": AnimalData(
            name: "Zebra",
            imageName: "Zebra",
            rarity: .common,
            description: "A striped zebra"
        ),
        "Sheep": AnimalData(
            name: "Sheep",
            imageName: "Uncommon_Sheep",
            rarity: .common,
            description: "A fluffy farm sheep"
        ),
        
        // Farm Animals
        "Chicken": AnimalData(
            name: "Chicken",
            imageName: "Common_Chicken",
            rarity: .common,
            description: "A common farm chicken"
        ),
        "Duck": AnimalData(
            name: "Duck",
            imageName: "Common_Duck",
            rarity: .common,
            description: "A common farm duck"
        ),
        "Mouse": AnimalData(
            name: "Mouse",
            imageName: "Common_Mouse",
            rarity: .common,
            description: "A common farm mouse"
        ),
        "Rabbit": AnimalData(
            name: "Rabbit",
            imageName: "Common_Rabbit",
            rarity: .common,
            description: "A common farm rabbit"
        ),
        "Goat": AnimalData(
            name: "Goat",
            imageName: "Uncommon_Goat",
            rarity: .rare,
            description: "An uncommon farm goat"
        ),
        "Pig": AnimalData(
            name: "Pig",
            imageName: "Uncommon_Pig",
            rarity: .rare,
            description: "An uncommon farm pig"
        ),
        "BorderCollie": AnimalData(
            name: "BorderCollie",
            imageName: "Rare_BorderCollie",
            rarity: .rare,
            description: "A rare farm border collie"
        ),
        "Cow": AnimalData(
            name: "Cow",
            imageName: "Rare_Cow",
            rarity: .rare,
            description: "A rare farm cow"
        ),
        "Turkey": AnimalData(
            name: "Turkey",
            imageName: "Rare_Turkey",
            rarity: .rare,
            description: "A rare farm turkey"
        ),
        "Horse": AnimalData(
            name: "Horse",
            imageName: "Epic_Horse",
            rarity: .epic,
            description: "An epic farm horse"
        ),
        "Scarecrow": AnimalData(
            name: "Scarecrow",
            imageName: "Legendary_Scarecrow",
            rarity: .legendary,
            description: "A legendary farm scarecrow"
        ),
        "Unicorn": AnimalData(
            name: "Unicorn",
            imageName: "Legendary_Unicorn",
            rarity: .legendary,
            description: "A legendary farm unicorn"
        ),
        "GoldenGoose": AnimalData(
            name: "GoldenGoose",
            imageName: "Mythic_GoldenGoose",
            rarity: .mythic,
            description: "A mythical golden goose"
        ),
        
        // Jungle Animals
        "Frog": AnimalData(
            name: "Frog",
            imageName: "Common_Frog",
            rarity: .common,
            description: "A common jungle frog"
        ),
        "Parrot": AnimalData(
            name: "Parrot",
            imageName: "Common_Parrot",
            rarity: .common,
            description: "A colorful jungle parrot"
        ),
        "Snake": AnimalData(
            name: "Snake",
            imageName: "Common_Snake",
            rarity: .common,
            description: "A common jungle snake"
        ),
        "Lemur": AnimalData(
            name: "Lemur",
            imageName: "Uncommon_Lemur",
            rarity: .uncommon,
            description: "An uncommon jungle lemur"
        ),
        "Koala": AnimalData(
            name: "Koala",
            imageName: "Uncommon_Koala",
            rarity: .uncommon,
            description: "An uncommon jungle koala"
        ),
        "Chameleon": AnimalData(
            name: "Chameleon",
            imageName: "Uncommon_Chamelon",
            rarity: .uncommon,
            description: "An uncommon color-changing chameleon"
        ),
        "Toucan": AnimalData(
            name: "Toucan",
            imageName: "Uncommon_Toucan",
            rarity: .uncommon,
            description: "An uncommon colorful toucan"
        ),
        "JungleElephant": AnimalData(
            name: "JungleElephant",
            imageName: "Uncommon_Elephant",
            rarity: .uncommon,
            description: "An uncommon jungle elephant"
        ),
        "Caiman": AnimalData(
            name: "Caiman",
            imageName: "Rare_Caiman",
            rarity: .rare,
            description: "A rare jungle caiman"
        ),
        "Capybara": AnimalData(
            name: "Capybara",
            imageName: "Rare_Capyabara",
            rarity: .rare,
            description: "A rare jungle capybara"
        ),
        "Jaguar": AnimalData(
            name: "Jaguar",
            imageName: "Epic_Jaguar",
            rarity: .epic,
            description: "An epic jungle jaguar"
        ),
        "Sloth": AnimalData(
            name: "Sloth",
            imageName: "Epic_Sloth",
            rarity: .epic,
            description: "A slow epic sloth"
        ),
        "Gorilla": AnimalData(
            name: "Gorilla",
            imageName: "Legendary_Gorilla",
            rarity: .legendary,
            description: "A legendary jungle gorilla"
        ),
        "SunGod": AnimalData(
            name: "SunGod",
            imageName: "Mythic-SunGod",
            rarity: .mythic,
            description: "A mythical sun god bear"
        ),
        
        // Arctic Animals
        "ArticFox": AnimalData(
            name: "ArticFox",
            imageName: "Common_ArticFox",
            rarity: .common,
            description: "A common arctic fox"
        ),
        "ArticHare": AnimalData(
            name: "ArticHare",
            imageName: "Common_ArticHare",
            rarity: .common,
            description: "A common arctic hare"
        ),
        "Seal": AnimalData(
            name: "Seal",
            imageName: "Common_Seal",
            rarity: .common,
            description: "A common arctic seal"
        ),
        "walrus": AnimalData(
            name: "walrus",
            imageName: "Common_walrus",
            rarity: .common,
            description: "A common arctic walrus"
        ),
        "ArticLemming": AnimalData(
            name: "ArticLemming",
            imageName: "Uncommon_ArticLemming",
            rarity: .rare,
            description: "An uncommon arctic lemming"
        ),
        "DallSheep": AnimalData(
            name: "DallSheep",
            imageName: "Uncommon_DallSheep",
            rarity: .rare,
            description: "An uncommon dall sheep"
        ),
        "ArcticPenguin": AnimalData(
            name: "ArcticPenguin",
            imageName: "Uncommon_Penguin",
            rarity: .rare,
            description: "An uncommon arctic penguin"
        ),
        "Ermine": AnimalData(
            name: "Ermine",
            imageName: "Rare_Ermine",
            rarity: .rare,
            description: "A rare arctic ermine"
        ),
        "Husky": AnimalData(
            name: "Husky",
            imageName: "Rare_Husky",
            rarity: .rare,
            description: "A rare arctic husky"
        ),
        "MuskOx": AnimalData(
            name: "MuskOx",
            imageName: "Rare_MuskOx",
            rarity: .rare,
            description: "A rare arctic musk ox"
        ),
        "Lynx": AnimalData(
            name: "Lynx",
            imageName: "Epic_Lynx",
            rarity: .epic,
            description: "An epic arctic lynx"
        ),
        "SnowLeopard": AnimalData(
            name: "SnowLeopard",
            imageName: "Epic_SnowLeopard",
            rarity: .epic,
            description: "An epic arctic snow leopard"
        ),
        "PolarBear": AnimalData(
            name: "PolarBear",
            imageName: "Legendary_PolarBear",
            rarity: .legendary,
            description: "A legendary arctic polar bear"
        ),
        "Rudolph": AnimalData(
            name: "Rudolph",
            imageName: "Legendary_Rudolph",
            rarity: .legendary,
            description: "A legendary arctic reindeer"
        ),
        "Yeti": AnimalData(
            name: "Yeti",
            imageName: "Mythic_Yeti",
            rarity: .mythic,
            description: "A mythical arctic yeti"
        ),
        
        // Add more animals here following this format:
        // "AnimalName": AnimalData(
        //     name: "AnimalName",
        //     imageName: "animalname",  // Must match Image Set name in Assets.xcassets
        //     rarity: .common,          // .common, .rare, .epic, or .legendary
        //     description: "Description here"
        // ),
    ]
    
    // MARK: - Helper Functions
    
    static func getAnimalData(for name: String) -> AnimalData? {
        return animals[name]
    }
    
    static func getImageName(for animalName: String) -> String {
        return animals[animalName]?.imageName ?? animalName.lowercased()
    }
    
    static func getAllAnimals() -> [AnimalData] {
        return Array(animals.values).sorted { $0.name < $1.name }
    }
    
    static func getAnimalsByRarity(_ rarity: AnimalRarity) -> [AnimalData] {
        return animals.values.filter { $0.rarity == rarity }
    }
}


