//
//  SanctuaryView.swift
//  Fauna
//
//  Fixed: Brace errors and Scope issues
//

import SwiftUI
import UIKit

struct SanctuaryView: View {
    private var gameData = GameDataManager.shared
    private var animalManager = AnimalManager.shared
    private var gridManager = GridManager.shared
    
    @State private var selectedView = "All"
    @State private var visibleInstances: [GameData.AnimalInstance] = []
    @State private var gridSize: Int = 3
    @State private var showingStatistics = false
    
    // Auto-fit zoom/pan (no user gestures — avoids broken zoom behavior)
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            AppColors.backgroundGreen
                .ignoresSafeArea()
            
            NavigationView {
                VStack(spacing: 0) {
                    // 1. Filter Buttons
                    HStack(spacing: 10) {
                        FilterButton(title: "All", selection: $selectedView)
                        FilterButton(title: "Day", selection: $selectedView)
                        FilterButton(title: "Week", selection: $selectedView)
                        FilterButton(title: "Month", selection: $selectedView)
                        FilterButton(title: "Year", selection: $selectedView)
                    }
                    .padding()
                    .padding(.top, 20)
                    .zIndex(10)
                    
                    // 2. Grid View Container (no user zoom/pan — auto-fit only)
                    GeometryReader { geometry in
                        GridView(
                            instances: visibleInstances,
                            gridSize: effectiveGridSize
                        )
                        .scaleEffect(zoomScale)
                        .offset(panOffset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .onAppear {
                            fitGridToScreen(in: geometry.size)
                        }
                        .onChange(of: gridSize) { _, _ in
                            withAnimation {
                                fitGridToScreen(in: geometry.size)
                            }
                        }
                        .onChange(of: visibleInstances.count) { _, _ in
                            // Keep grid size in sync so we never have more instances than cells (avoids crash past 9)
                            gridSize = gridManager.getGridSize()
                            // Auto-adjust zoom when new animals are added
                            withAnimation {
                                fitGridToScreen(in: geometry.size)
                            }
                        }
                    }
                }
                .background(AppColors.backgroundGreen)
                .navigationTitle("Sanctuary")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppColors.backgroundGreen, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingStatistics = true
                        }) {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.white)
                        }
                    }
                }
                .sheet(isPresented: $showingStatistics) {
                    StatisticsView()
                }
                .onAppear {
                    processPendingItems()
                    // First paint: load without mutating GameDataManager (skipReposition) to avoid crash when swapping to tab
                    DispatchQueue.main.async {
                        updateVisibleInstances(skipReposition: true)
                    }
                    // Second pass after layout: reposition out-of-bounds instances (mutates after view is stable)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        updateVisibleInstances(skipReposition: false)
                    }
                }
                .onChange(of: selectedView) { oldValue, newValue in
                    gridManager.reorganizeForView(newValue)
                    updateVisibleInstances(skipReposition: false)
                    // Reset zoom/pan when filter changes
                    withAnimation {
                        panOffset = .zero
                        zoomScale = 1.0
                    }
                }
            }
        }
    }
    
    // --- Helper Methods inside SanctuaryView ---
    
    /// Grid size used for layout; always at least large enough to fit all visible instances (avoids crash when adding 10th item).
    private var effectiveGridSize: Int {
        let minSize = visibleInstances.isEmpty ? 3 : Int(ceil(sqrt(Double(visibleInstances.count))))
        return max(3, max(gridSize, minSize))
    }

    private func fitGridToScreen(in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let baseTileWidth: CGFloat = 128
        let baseTileHeight: CGFloat = 64
        let sizeToFit = effectiveGridSize
        let gridPixelWidth = CGFloat(sizeToFit) * baseTileWidth
        let gridPixelHeight = CGFloat(sizeToFit) * baseTileHeight
        
        let targetWidth = gridPixelWidth * 1.2
        let targetHeight = gridPixelHeight * 1.2
        guard targetWidth > 0, targetHeight > 0 else { return }
        
        let widthScale = size.width / targetWidth
        let heightScale = size.height / targetHeight
        let fitScale = min(widthScale, heightScale)
        guard fitScale.isFinite, fitScale > 0 else { return }
        
        zoomScale = min(max(fitScale, 0.3), 1.2)
        panOffset = CGSize(width: 0, height: 50)
    }
    
    private func processPendingItems() {
        gameData.processPendingAnimal()
        gameData.processUnlockedGraves()
    }
    
    private func updateVisibleInstances(skipReposition: Bool = false) {
        let raw = gridManager.getVisibleInstances(for: selectedView, skipReposition: skipReposition)
        // Deduplicate by id so ForEach(instances, id: \.id) never sees duplicates (SwiftUI crashes on duplicate ids)
        var seen = Set<String>()
        visibleInstances = raw.filter { seen.insert($0.id).inserted }
        gridSize = max(3, gridManager.getGridSize())
    }
}


// --- SUBVIEWS (Must be OUTSIDE SanctuaryView) ---

struct FilterButton: View {
    let title: String
    @Binding var selection: String
    
    var isSelected: Bool {
        selection == title
    }
    
    var body: some View {
        Button(action: {
            withAnimation {
                selection = title
            }
        }) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.buttonGreen : AppColors.backgroundGreen.opacity(0.6))
                .cornerRadius(8)
        }
    }
}

struct GridView: View {
    let instances: [GameData.AnimalInstance]
    let gridSize: Int
    
    private let tileWidth: CGFloat = 128
    private let tileHeight: CGFloat = 64
    
    init(instances: [GameData.AnimalInstance], gridSize: Int) {
        // Deduplicate by id to avoid ForEach crash on duplicate ids
        var seen = Set<String>()
        self.instances = instances.filter { !$0.id.isEmpty && seen.insert($0.id).inserted }
        self.gridSize = max(3, gridSize)
    }
    
    var body: some View {
        let halfSize = gridSize / 2
        // Stable id per cell (x,y) so view identity doesn't change when grid size changes — avoids SwiftUI crash
        let cellPositions: [(id: String, x: Int, y: Int)] = (-halfSize..<(-halfSize + gridSize)).flatMap { x in
            (-halfSize..<(-halfSize + gridSize)).map { y in (id: "\(x)-\(y)", x: x, y: y) }
        }
        
        ZStack {
            // 1. Draw Ground
            ForEach(cellPositions, id: \.id) { cell in
                let pos = isometricToScreen(x: cell.x, y: cell.y)
                let zIndex = Double(cell.x + cell.y)
                
                GrassTileView()
                    .frame(width: tileWidth, height: tileHeight)
                    .position(x: pos.x, y: pos.y)
                    .zIndex(zIndex)
            }
            
            // 2. Draw Animals/Graves
            ForEach(instances, id: \.id) { instance in
                if !instance.id.isEmpty {
                    AnimalInstanceView(instance: instance, tileWidth: tileWidth, tileHeight: tileHeight)
                }
            }
        }
        .frame(width: 0, height: 0) // Center in parent
    }
    
    private func isometricToScreen(x: Int, y: Int) -> CGPoint {
        let screenX = CGFloat(x - y) * (tileWidth / 2)
        let screenY = CGFloat(x + y) * (tileHeight / 2)
        return CGPoint(x: screenX, y: screenY)
    }
}

struct AnimalInstanceView: View {
    let instance: GameData.AnimalInstance
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    
    var body: some View {
        let pos = isometricToScreen(x: instance.gridPosition.x, y: instance.gridPosition.y)
        let gameData = GameDataManager.shared
        let animalOffset = gameData.getAnimalOffset()
        
        // Sprite sizes — keep within tile bounds to avoid overlap
        let spriteWidth: CGFloat = tileWidth * 0.55
        let spriteHeight: CGFloat = instance.isGrave ? tileHeight * 1.0 : spriteWidth
        
        // Position sprite so its bottom "feet" sit at the tile's visual center (diamond center).
        // .position() places the view's center, so shift up by half the sprite height.
        let finalX = pos.x + CGFloat(animalOffset.x)
        let finalY = pos.y - (spriteHeight / 2) + CGFloat(animalOffset.y)
        let objectZIndex = Double(instance.gridPosition.x + instance.gridPosition.y) + 100.0
        
        Group {
            if instance.isGrave {
                GraveCard(instance: instance)
                    .frame(width: spriteWidth, height: spriteHeight)
            } else {
                AnimalGridCard(instance: instance)
                    .frame(width: spriteWidth, height: spriteHeight)
            }
        }
        .position(x: finalX, y: finalY)
        .zIndex(objectZIndex)
    }
    
    private func isometricToScreen(x: Int, y: Int) -> CGPoint {
        let screenX = CGFloat(x - y) * (tileWidth / 2)
        let screenY = CGFloat(x + y) * (tileHeight / 2)
        return CGPoint(x: screenX, y: screenY)
    }
}

struct GrassTileView: View {
    /// Load the grass image once and share across all tile instances.
    private static let grassImage: UIImage? = UIImage(named: "grass")

    var body: some View {
        Group {
            if let image = Self.grassImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // Fallback shape
                Path { path in
                    path.move(to: CGPoint(x: 64, y: 0))
                    path.addLine(to: CGPoint(x: 128, y: 32))
                    path.addLine(to: CGPoint(x: 64, y: 64))
                    path.addLine(to: CGPoint(x: 0, y: 32))
                }
                .fill(Color.green.opacity(0.4))
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: 64, y: 0))
                        path.addLine(to: CGPoint(x: 128, y: 32))
                        path.addLine(to: CGPoint(x: 64, y: 64))
                        path.addLine(to: CGPoint(x: 0, y: 32))
                    }
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}

struct AnimalGridCard: View {
    let instance: GameData.AnimalInstance
    
    init(instance: GameData.AnimalInstance) {
        self.instance = instance
    }
    
    var body: some View {
        Group {
            let animalManager = AnimalManager.shared
            let imageName = animalManager.getImageName(for: instance.animalName)
            
            if let config = AnimationFrameDetector.getAnimationConfig(for: instance.animalName) {
                AnimatedSpriteView(
                    baseName: instance.animalName,
                    animationName: config.animationName,
                    frameCount: config.frameCount,
                    frameDuration: config.frameDuration,
                    startFrame: config.startFrame,
                    frameFormat: config.frameFormat
                )
            }
            else if UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

struct GraveCard: View {
    let instance: GameData.AnimalInstance
    
    var body: some View {
        Group {
            if UIImage(named: "grave") != nil {
                Image("grave")
                    .resizable()
                    .scaledToFit()
                    .colorMultiply(graveColor)
            } else {
                VStack(spacing: 0) {
                    Image(systemName: "cross.fill")
                        .font(.system(size: 20))
                    RoundedRectangle(cornerRadius: 8)
                        .frame(height: 40)
                }
                .foregroundColor(graveColor)
            }
        }
        .shadow(radius: 2)
    }
    
    private var graveColor: Color {
        if instance.eggType == "JungleEgg" {
            return Color(red: 0.341, green: 0.818, blue: 1.0)
        }
        return Color.gray
    }
}

// MARK: - Statistics View

struct StatisticsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var gameData = GameDataManager.shared
    @StateObject private var animalManager = AnimalManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundGreen
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Total Stats Section
                        StatCard(title: "Total Coins", value: "\(gameData.getTotalCoins())", icon: "circle.fill", color: AppColors.coinGold)
                        
                        StatCard(title: "Total Animals", value: "\(totalAnimals)", icon: "pawprint.fill", color: .white)
                        
                        StatCard(title: "Total Graves", value: "\(totalGraves)", icon: "cross.fill", color: .gray)
                        
                        // Hatch Statistics Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Hatch Statistics")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            StatRow(title: "Today", value: "\(gameData.getDailyHatchCount())")
                            StatRow(title: "This Week", value: "\(gameData.getWeeklyHatchCount())")
                            StatRow(title: "This Month", value: "\(gameData.getMonthlyHatchCount())")
                            StatRow(title: "This Year", value: "\(gameData.getYearlyHatchCount())")
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Rarity Breakdown Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Animals by Rarity")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            RarityRow(rarity: "Common", count: rarityCounts[.common] ?? 0, color: .gray)
                            RarityRow(rarity: "Uncommon", count: rarityCounts[.uncommon] ?? 0, color: .green)
                            RarityRow(rarity: "Rare", count: rarityCounts[.rare] ?? 0, color: .blue)
                            RarityRow(rarity: "Epic", count: rarityCounts[.epic] ?? 0, color: .purple)
                            RarityRow(rarity: "Legendary", count: rarityCounts[.legendary] ?? 0, color: .yellow)
                            RarityRow(rarity: "Mythic", count: rarityCounts[.mythic] ?? 0, color: .orange)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Estimated Study Time
                        if estimatedStudyHours > 0 {
                            StatCard(
                                title: "Estimated Study Time",
                                value: String(format: "%.1f hours", estimatedStudyHours),
                                icon: "clock.fill",
                                color: AppColors.buttonGreen
                            )
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    // Computed properties for statistics
    private var totalAnimals: Int {
        let instances = gameData.getAnimalInstances()
        return instances.filter { !$0.isGrave }.count
    }
    
    private var totalGraves: Int {
        let instances = gameData.getAnimalInstances()
        return instances.filter { $0.isGrave }.count
    }
    
    private var rarityCounts: [AnimalRarity: Int] {
        let instances = gameData.getAnimalInstances().filter { !$0.isGrave }
        var counts: [AnimalRarity: Int] = [:]
        
        for instance in instances {
            if let animalData = AnimalDatabase.getAnimalData(for: instance.animalName) {
                counts[animalData.rarity, default: 0] += 1
            }
        }
        
        return counts
    }
    
    private var estimatedStudyHours: Double {
        // Estimate based on hatch counts (assuming average 30 min per hatch)
        let totalHatches = gameData.getYearlyHatchCount()
        return Double(totalHatches) * 0.5 // 30 minutes = 0.5 hours per hatch
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
    }
}

struct RarityRow: View {
    let rarity: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(rarity)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text("\(count)")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
    }
}
