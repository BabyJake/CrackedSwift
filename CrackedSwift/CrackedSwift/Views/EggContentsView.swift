//
//  EggContentsView.swift
//  Fauna
//
//  Shows all animals in an egg — unlocked ones revealed, locked ones as "?"
//

import SwiftUI

struct EggContentsView: View {
    let egg: Egg
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameData = GameDataManager.shared
    
    private var unlockedAnimals: Set<String> {
        Set(gameData.getUnlockedAnimals())
    }
    
    /// Animals grouped by rarity, ordered from common → mythic
    private var animalsByRarity: [(rarity: AnimalRarity, animals: [AnimalSpawnChance])] {
        let order: [AnimalRarity] = [.common, .uncommon, .rare, .epic, .legendary, .mythic]
        
        var grouped: [AnimalRarity: [AnimalSpawnChance]] = [:]
        for chance in egg.animalSpawnChances {
            let rarity = AnimalDatabase.getAnimalData(for: chance.animalName)?.rarity ?? .common
            grouped[rarity, default: []].append(chance)
        }
        
        return order.compactMap { rarity in
            guard let animals = grouped[rarity], !animals.isEmpty else { return nil }
            return (rarity: rarity, animals: animals)
        }
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 12)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Egg header
                    eggHeader
                    
                    // Progress bar
                    progressSection
                    
                    // Animal grid grouped by rarity
                    ForEach(animalsByRarity, id: \.rarity) { group in
                        raritySection(rarity: group.rarity, animals: group.animals)
                    }
                }
                .padding()
            }
            .background(AppColors.backgroundGreen.ignoresSafeArea())
            .navigationTitle(egg.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    // MARK: - Egg Header
    
    private var eggHeader: some View {
        VStack(spacing: 12) {
            if UIImage(named: egg.imageName) != nil {
                Image(egg.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
            } else {
                Image(systemName: "oval.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Text(egg.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // MARK: - Progress
    
    private var progressSection: some View {
        let total = egg.animalSpawnChances.count
        let unlocked = egg.animalSpawnChances.filter { unlockedAnimals.contains($0.animalName) }.count
        
        return VStack(spacing: 6) {
            Text("\(unlocked) / \(total) Discovered")
                .font(.headline)
                .foregroundColor(.white)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.15))
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.buttonGreen)
                        .frame(width: total > 0 ? geo.size.width * CGFloat(unlocked) / CGFloat(total) : 0)
                }
            }
            .frame(height: 10)
        }
    }
    
    // MARK: - Rarity Section
    
    private func raritySection(rarity: AnimalRarity, animals: [AnimalSpawnChance]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Rarity header
            HStack(spacing: 6) {
                Circle()
                    .fill(AppColors.color(for: rarity))
                    .frame(width: 10, height: 10)
                
                Text(rarity.rawValue.capitalized)
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.color(for: rarity))
            }
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(animals, id: \.animalName) { chance in
                    animalCell(chance: chance)
                }
            }
        }
    }
    
    // MARK: - Animal Cell
    
    private func animalCell(chance: AnimalSpawnChance) -> some View {
        let isUnlocked = unlockedAnimals.contains(chance.animalName)
        let animalData = AnimalDatabase.getAnimalData(for: chance.animalName)
        let rarity = animalData?.rarity ?? .common
        
        return VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isUnlocked ? AppColors.color(for: rarity).opacity(0.6) : Color.white.opacity(0.1),
                                lineWidth: 1.5
                            )
                    )
                
                if isUnlocked {
                    // Show actual animal image
                    let imageName = AnimalDatabase.getImageName(for: chance.animalName)
                    if UIImage(named: imageName) != nil {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    } else {
                        Image(systemName: "pawprint.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.color(for: rarity))
                    }
                } else {
                    // Mystery silhouette
                    Text("?")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white.opacity(0.25))
                }
            }
            .frame(width: 72, height: 72)
            
            // Name or ???
            Text(isUnlocked ? chance.animalName : "???")
                .font(.caption2)
                .fontWeight(isUnlocked ? .medium : .regular)
                .foregroundColor(isUnlocked ? AppColors.color(for: rarity) : .white.opacity(0.3))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

#Preview {
    EggContentsView(egg: ShopDatabase.default.shopItems[0])
}
