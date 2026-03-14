//
//  ShopView.swift
//  Fauna
//
//  Replaces: EggShopManager.cs and shop scene
//

import SwiftUI

struct ShopView: View {
    @StateObject private var shopManager = ShopManager.shared
    @StateObject private var gameData = GameDataManager.shared
    
    // Sorted eggs by cost (cheapest first)
    private var sortedEggs: [Egg] {
        shopManager.shopDatabase.shopItems.sorted { $0.baseCost < $1.baseCost }
    }
    
    var body: some View {
        ZStack {
            AppColors.backgroundGreen
                .ignoresSafeArea()
            
        NavigationView {
            VStack {
                // Coin Display
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                Text("Coins: \(gameData.getTotalCoins())")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            Image(systemName: "circle.fill")
                                .foregroundColor(AppColors.coinGold)
                                .overlay(
                                    Image(systemName: "pawprint.fill")
                                        .foregroundColor(AppColors.coinBrown)
                                        .font(.system(size: 12))
                                )
                                .frame(width: 24, height: 24)
                        }
                    .padding()
                    }
                
                // Shop Items
                List {
                    ForEach(sortedEggs) { egg in
                        ShopItemRow(egg: egg)
                    }
                }
                    .scrollContentBackground(.hidden)
                    .background(AppColors.backgroundGreen)
                }
                .navigationTitle("Shop")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

struct ShopItemRow: View {
    let egg: Egg
    @StateObject private var shopManager = ShopManager.shared
    @StateObject private var gameData = GameDataManager.shared
    @State private var showingPurchaseAlert = false
    @State private var purchaseSuccess = false
    @State private var showingEggContents = false
    
    var canAfford: Bool {
        shopManager.canAffordEgg(egg)
    }
    
    var quantity: Int {
        shopManager.getQuantity(for: egg.title)
    }
    
    var body: some View {
        HStack {
            // Egg image - tap to see contents
            Group {
                if UIImage(named: egg.imageName) != nil {
                    Image(egg.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                } else {
                    Image(systemName: "oval.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .onTapGesture { showingEggContents = true }
            .padding(.trailing, 12)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(egg.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(egg.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Cost: \(egg.baseCost) coins")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                if quantity > 0 {
                    Text("Owned: \(quantity)")
                        .font(.caption)
                        .foregroundColor(AppColors.buttonGreen)
                }
            }
            
            Spacer()
            
            Button(action: {
                if shopManager.purchaseEgg(egg) {
                    purchaseSuccess = true
                    showingPurchaseAlert = true
                } else {
                    purchaseSuccess = false
                    showingPurchaseAlert = true
                }
            }) {
                Text(canAfford ? "Buy" : "Can't Afford")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(canAfford ? AppColors.buttonGreen : Color.gray.opacity(0.5))
                    .cornerRadius(8)
            }
            .disabled(!canAfford)
        }
        .padding(.vertical, 8)
        .listRowBackground(AppColors.backgroundGreen)
        .alert(isPresented: $showingPurchaseAlert) {
            Alert(
                title: Text(purchaseSuccess ? "Purchase Successful!" : "Not Enough Coins"),
                message: Text(purchaseSuccess ? "You purchased \(egg.title)" : "You need \(egg.baseCost - gameData.getTotalCoins()) more coins"),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showingEggContents) {
            EggContentsView(egg: egg)
        }
    }
}

#Preview {
    ShopView()
}

