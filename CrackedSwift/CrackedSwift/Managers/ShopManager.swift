//
//  ShopManager.swift
//  Fauna
//
//  Replaces: EggShopManager.cs and PurchasedEggManager.cs
//

import Foundation

@MainActor
class ShopManager: ObservableObject {
    static let shared = ShopManager()
    
    @Published var shopDatabase = ShopDatabase.default
    private let dataManager = GameDataManager.shared
    
    private init() {}
    
    // MARK: - Purchase
    
    func purchaseEgg(_ egg: Egg) -> Bool {
        // Check if we have enough coins
        guard dataManager.getTotalCoins() >= egg.baseCost else {
            return false
        }
        
        // Spend coins first
        guard dataManager.spendCoins(egg.baseCost) else {
            return false
        }
        
        // Add egg to purchased eggs
        dataManager.purchaseEgg(egg.title)
        
        // Automatically select the egg if no egg is currently selected
        if dataManager.getCurrentEgg() == nil {
            dataManager.setCurrentEgg(egg.title)
        }
        
        return true
    }
    
    func canAffordEgg(_ egg: Egg) -> Bool {
        return dataManager.getTotalCoins() >= egg.baseCost
    }
    
    func getPurchasedEggs() -> [String: Int] {
        return dataManager.getPurchasedEggs()
    }
    
    func getQuantity(for eggTitle: String) -> Int {
        return dataManager.getPurchasedEggs()[eggTitle] ?? 0
    }
    
    func selectEgg(_ eggTitle: String, instanceId: String? = nil) {
        dataManager.setCurrentEgg(eggTitle, instanceId: instanceId)
    }
    
    func getCurrentEgg() -> String? {
        return dataManager.getCurrentEgg()
    }
    
    func getCurrentEggInstanceId() -> String? {
        return dataManager.getCurrentEggInstanceId()
    }
    
    func getEggByTitle(_ title: String) -> Egg? {
        return shopDatabase.shopItems.first { $0.title == title }
    }
    
    /// Finds the next available egg after the current one is exhausted
    /// Returns the next egg that has quantity > 0, or Piggybank if no other eggs available
    func getNextAvailableEgg(excluding currentEggTitle: String?) -> String? {
        let purchasedEggs = dataManager.getPurchasedEggs()
        
        // First, try to find any egg with quantity > 0 (excluding current)
        for (eggTitle, quantity) in purchasedEggs {
            if eggTitle != currentEggTitle && quantity > 0 {
                return eggTitle
            }
        }
        
        // If no other eggs found, return Piggybank (always available)
        return "Piggybank"
    }
}

