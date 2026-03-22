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
    @StateObject private var gridManager = GridManager.shared
    
    @State private var selectedView = "All"
    @State private var visibleInstances: [GameData.AnimalInstance] = []
    @State private var gridSize: Int = 3
    @State private var showingStatistics = false
    @State private var showingAnimalDetail: GameData.AnimalInstance? = nil
    
    // Auto-fit zoom/pan (no user gestures — avoids broken zoom behavior)
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Layered nature background
            LinearGradient(
                colors: [
                    Color(hex: "#2D5A3F"),
                    Color(hex: "#3D7A5F"),
                    Color(hex: "#4A8B6E")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            NavigationView {
                VStack(spacing: 0) {
                    // Animal count header
                    HStack {
                        let animalCount = visibleInstances.filter { !$0.isShell }.count
                        let shellCount = visibleInstances.filter { $0.isShell }.count
                        
                        HStack(spacing: 6) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#8BC49E"))
                            Text("\(animalCount) creature\(animalCount == 1 ? "" : "s")")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if shellCount > 0 {
                            Text("\u{00B7}")
                                .foregroundColor(.white.opacity(0.3))
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                                Text("\(shellCount)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    
                    // Filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["All", "Day", "Week", "Month", "Year"], id: \.self) { filter in
                                FilterPill(title: filter, isSelected: selectedView == filter) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedView = filter
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 8)
                    .zIndex(10)
                    
                    // Drag instruction banner
                    if gridManager.draggingInstanceId != nil {
                        HStack(spacing: 8) {
                            Image(systemName: "wind")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#F4D9A0"))
                            
                            Text(gridManager.targetGridPosition != nil
                                 ? "Release to place here"
                                 : "Slide to a new patch")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.25))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: "#F4D9A0").opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(10)
                    }
                    
                    // 2. Grid View Container (no user zoom/pan — auto-fit only)
                    GeometryReader { geometry in
                        GridView(
                            instances: visibleInstances,
                            gridSize: effectiveGridSize,
                            draggingInstanceId: gridManager.draggingInstanceId,
                            dragOffset: gridManager.dragOffset,
                            targetGridPosition: gridManager.targetGridPosition,
                            onAnimalTapped: { instance in
                                showingAnimalDetail = instance
                            },
                            onDragChanged: { instance, translation in
                                if gridManager.draggingInstanceId == nil {
                                    gridManager.startDragging(instance.id)
                                }
                                gridManager.updateDrag(offset: translation, fromPosition: instance.gridPosition)
                            },
                            onDragEnded: { instance in
                                gridManager.endDrag()
                                updateVisibleInstances(skipReposition: false)
                            }
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
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#2D5A3F"), Color(hex: "#3D7A5F"), Color(hex: "#4A8B6E")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .navigationTitle("Sanctuary")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color(hex: "#2D5A3F"), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingStatistics = true
                        }) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "#8BC49E"))
                        }
                    }
                }
                .sheet(isPresented: $showingStatistics) {
                    StatisticsView()
                }
                .sheet(item: $showingAnimalDetail, onDismiss: {
                    // Refresh grid after detail sheet closes (shell may have been removed)
                    updateVisibleInstances(skipReposition: false)
                }) { instance in
                    AnimalDetailSheet(instance: instance)
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
        gameData.processUnlockedShells()
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

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(isSelected ? Color(hex: "#2D5A3F") : .white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: "#A8E6C3") : Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }
}

struct GridView: View {
    let instances: [GameData.AnimalInstance]
    let gridSize: Int
    let draggingInstanceId: String?
    let dragOffset: CGSize
    let targetGridPosition: GameData.GridPosition?
    var onAnimalTapped: ((GameData.AnimalInstance) -> Void)? = nil
    var onDragChanged: ((GameData.AnimalInstance, CGSize) -> Void)? = nil
    var onDragEnded: ((GameData.AnimalInstance) -> Void)? = nil
    
    private let tileWidth: CGFloat = 128
    private let tileHeight: CGFloat = 64
    
    init(instances: [GameData.AnimalInstance], gridSize: Int, draggingInstanceId: String? = nil, dragOffset: CGSize = .zero, targetGridPosition: GameData.GridPosition? = nil, onAnimalTapped: ((GameData.AnimalInstance) -> Void)? = nil, onDragChanged: ((GameData.AnimalInstance, CGSize) -> Void)? = nil, onDragEnded: ((GameData.AnimalInstance) -> Void)? = nil) {
        var seen = Set<String>()
        self.instances = instances.filter { !$0.id.isEmpty && seen.insert($0.id).inserted }
        self.gridSize = max(3, gridSize)
        self.draggingInstanceId = draggingInstanceId
        self.dragOffset = dragOffset
        self.targetGridPosition = targetGridPosition
        self.onAnimalTapped = onAnimalTapped
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }
    
    var body: some View {
        let halfSize = gridSize / 2
        let cellPositions: [(id: String, x: Int, y: Int)] = (-halfSize..<(-halfSize + gridSize)).flatMap { x in
            (-halfSize..<(-halfSize + gridSize)).map { y in (id: "\(x)-\(y)", x: x, y: y) }
        }
        
        ZStack {
            // 1. Draw Ground + target highlight
            ForEach(cellPositions, id: \.id) { cell in
                let pos = isometricToScreen(x: cell.x, y: cell.y)
                let zIndex = Double(cell.x + cell.y)
                let gridPos = GameData.GridPosition(x: cell.x, y: cell.y)
                let isDropTarget = targetGridPosition == gridPos
                
                ZStack {
                    GrassTileView()
                    
                    // Highlight the drop target tile
                    if isDropTarget {
                        Path { path in
                            path.move(to: CGPoint(x: 64, y: 0))
                            path.addLine(to: CGPoint(x: 128, y: 32))
                            path.addLine(to: CGPoint(x: 64, y: 64))
                            path.addLine(to: CGPoint(x: 0, y: 32))
                            path.closeSubpath()
                        }
                        .fill(
                            RadialGradient(
                                colors: [Color(hex: "#A8E6C3").opacity(0.5), Color(hex: "#6ECB9B").opacity(0.15)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .overlay(
                            Path { path in
                                path.move(to: CGPoint(x: 64, y: 0))
                                path.addLine(to: CGPoint(x: 128, y: 32))
                                path.addLine(to: CGPoint(x: 64, y: 64))
                                path.addLine(to: CGPoint(x: 0, y: 32))
                                path.closeSubpath()
                            }
                            .stroke(Color(hex: "#A8E6C3").opacity(0.6), lineWidth: 1.5)
                        )
                        .allowsHitTesting(false)
                    }
                }
                .frame(width: tileWidth, height: tileHeight)
                .position(x: pos.x, y: pos.y)
                .zIndex(zIndex)
            }
            
            // 2. Draw Animals/Shells
            ForEach(instances, id: \.id) { instance in
                if !instance.id.isEmpty {
                    let isDragging = draggingInstanceId == instance.id
                    let currentDragOffset = isDragging ? dragOffset : .zero
                    
                    AnimalInstanceView(
                        instance: instance,
                        tileWidth: tileWidth,
                        tileHeight: tileHeight,
                        isDragging: isDragging,
                        dragOffset: currentDragOffset
                    )
                    .gesture(
                        LongPressGesture(minimumDuration: 0.3)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { value in
                                switch value {
                                case .second(true, let drag):
                                    if let drag = drag {
                                        if draggingInstanceId == nil {
                                            onDragChanged?(instance, .zero)
                                        }
                                        onDragChanged?(instance, drag.translation)
                                    }
                                default:
                                    break
                                }
                            }
                            .onEnded { value in
                                switch value {
                                case .second(true, _):
                                    onDragEnded?(instance)
                                default:
                                    break
                                }
                            }
                    )
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            if draggingInstanceId == nil {
                                onAnimalTapped?(instance)
                            }
                        }
                    )
                }
            }
        }
        .frame(width: 0, height: 0)
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
    var isDragging: Bool = false
    var dragOffset: CGSize = .zero
    
    var body: some View {
        let pos = isometricToScreen(x: instance.gridPosition.x, y: instance.gridPosition.y)
        let gameData = GameDataManager.shared
        let animalOffset = gameData.getAnimalOffset()
        
        // Sprite sizes — keep within tile bounds to avoid overlap
        let spriteWidth: CGFloat = tileWidth * 0.55
        let spriteHeight: CGFloat = instance.isShell ? tileHeight * 1.0 : spriteWidth
        
        let finalX = pos.x + CGFloat(animalOffset.x) + dragOffset.width
        let finalY = pos.y - (spriteHeight / 2) + CGFloat(animalOffset.y) + dragOffset.height
        let objectZIndex = isDragging ? 500.0 : Double(instance.gridPosition.x + instance.gridPosition.y) + 100.0
        
        Group {
            if instance.isShell {
                ShellCard(instance: instance)
                    .frame(width: spriteWidth, height: spriteHeight)
            } else {
                AnimalGridCard(instance: instance)
                    .frame(width: spriteWidth, height: spriteHeight)
            }
        }
        // Drag visual feedback
        .shadow(color: isDragging ? Color(hex: "#2D5A3F").opacity(0.5) : .clear, radius: isDragging ? 10 : 0, x: 0, y: isDragging ? 8 : 0)
        .scaleEffect(isDragging ? 1.15 : 1.0)
        .opacity(isDragging ? 0.95 : 1.0)
        .rotation3DEffect(.degrees(isDragging ? 2 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
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

struct ShellCard: View {
    let instance: GameData.AnimalInstance
    
    var body: some View {
        Group {
            if UIImage(named: "shell") != nil {
                Image("shell")
                    .resizable()
                    .scaledToFit()
                    .colorMultiply(shellColor)
            } else {
                VStack(spacing: 0) {
                    Image(systemName: "egg.fill")
                        .font(.system(size: 20))
                    RoundedRectangle(cornerRadius: 8)
                        .frame(height: 40)
                }
                .foregroundColor(shellColor)
            }
        }
        .shadow(radius: 2)
    }
    
    private var shellColor: Color {
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
                LinearGradient(
                    colors: [Color(hex: "#2D5A3F"), Color(hex: "#3D7A5F")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Summary row
                        HStack(spacing: 12) {
                            MiniStatBubble(icon: "leaf.fill", value: "\(totalAnimals)", label: "Animals", tint: Color(hex: "#A8E6C3"))
                            MiniStatBubble(icon: "circle.fill", value: "\(gameData.getTotalCoins())", label: "Coins", tint: AppColors.coinGold)
                            MiniStatBubble(icon: "xmark.circle", value: "\(totalShells)", label: "Shells", tint: Color.white.opacity(0.5))
                        }
                        .padding(.horizontal)
                        
                        // Hatch Statistics
                        NatureCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 6) {
                                    Image(systemName: "bird.fill")
                                        .foregroundColor(Color(hex: "#A8E6C3"))
                                        .font(.system(size: 14))
                                    Text("Hatch History")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                
                                NatureStatRow(label: "Today", value: "\(gameData.getDailyHatchCount())")
                                NatureStatRow(label: "This Week", value: "\(gameData.getWeeklyHatchCount())")
                                NatureStatRow(label: "This Month", value: "\(gameData.getMonthlyHatchCount())")
                                NatureStatRow(label: "This Year", value: "\(gameData.getYearlyHatchCount())")
                            }
                        }
                        
                        // Rarity Breakdown
                        NatureCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(Color(hex: "#F4D9A0"))
                                        .font(.system(size: 14))
                                    Text("By Rarity")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                
                                NatureRarityRow(rarity: "Common", count: rarityCounts[.common] ?? 0, color: Color.white.opacity(0.5))
                                NatureRarityRow(rarity: "Uncommon", count: rarityCounts[.uncommon] ?? 0, color: Color(hex: "#8BC49E"))
                                NatureRarityRow(rarity: "Rare", count: rarityCounts[.rare] ?? 0, color: Color(hex: "#6BA3D6"))
                                NatureRarityRow(rarity: "Epic", count: rarityCounts[.epic] ?? 0, color: Color(hex: "#B48CD6"))
                                NatureRarityRow(rarity: "Legendary", count: rarityCounts[.legendary] ?? 0, color: Color(hex: "#F4D9A0"))
                                NatureRarityRow(rarity: "Mythic", count: rarityCounts[.mythic] ?? 0, color: Color(hex: "#F4A66A"))
                            }
                        }
                        
                        // Study Time
                        if totalStudyTimeSeconds > 0 {
                            NatureCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "clock.fill")
                                                .foregroundColor(Color(hex: "#A8E6C3"))
                                                .font(.system(size: 14))
                                            Text("Total Focus Time")
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white)
                                        }
                                        Text(formattedStudyTime)
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .foregroundColor(Color(hex: "#A8E6C3"))
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#2D5A3F"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#A8E6C3"))
                }
            }
        }
    }
    
    // Computed properties for statistics
    private var totalAnimals: Int {
        let instances = gameData.getAnimalInstances()
        return instances.filter { !$0.isShell }.count
    }
    
    private var totalShells: Int {
        let instances = gameData.getAnimalInstances()
        return instances.filter { $0.isShell }.count
    }
    
    private var rarityCounts: [AnimalRarity: Int] {
        let instances = gameData.getAnimalInstances().filter { !$0.isShell }
        var counts: [AnimalRarity: Int] = [:]
        
        for instance in instances {
            if let animalData = AnimalDatabase.getAnimalData(for: instance.animalName) {
                counts[animalData.rarity, default: 0] += 1
            }
        }
        
        return counts
    }
    
    private var totalStudyTimeSeconds: TimeInterval {
        return gameData.getTotalStudyTime()
    }
    
    private var formattedStudyTime: String {
        let totalSeconds = totalStudyTimeSeconds
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Nature-Themed Stat Components

struct MiniStatBubble: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(tint)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

struct NatureCard<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal)
    }
}

struct NatureStatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

struct NatureRarityRow: View {
    let rarity: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(rarity)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text("\(count)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Animal Detail Sheet

struct AnimalDetailSheet: View {
    let instance: GameData.AnimalInstance
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreManager.shared
    @State private var showRemoveConfirmation = false
    @State private var isRemoving = false
    @State private var removalSuccess = false
    
    private var animalData: AnimalData? {
        AnimalDatabase.getAnimalData(for: instance.animalName)
    }
    
    private var rarityColor: Color {
        if let data = animalData {
            return AppColors.color(for: data.rarity)
        }
        return .gray
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#2D5A3F"), Color(hex: "#3D7A5F")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 8)
                        
                        if instance.isShell {
                            shellDetailContent
                        } else {
                            animalDetailContent
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#2D5A3F"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#A8E6C3"))
                }
            }
            .alert("Remove Shell", isPresented: $showRemoveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    Task {
                        isRemoving = true
                        let success = await storeManager.purchaseShellRemoval(shellInstanceId: instance.id)
                        isRemoving = false
                        if success {
                            removalSuccess = true
                            // Auto-dismiss after a brief moment
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                dismiss()
                            }
                        }
                    }
                }
            } message: {
                if let product = storeManager.removeShellProduct {
                    Text("Remove this shell from your sanctuary for \(product.displayPrice)?")
                } else {
                    Text("Remove this shell from your sanctuary for £0.99?")
                }
            }
        }
    }
    
    // MARK: - Shell Detail Content
    
    @ViewBuilder
    private var shellDetailContent: some View {
        // Shell image
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.03)],
                        center: .center,
                        startRadius: 40,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
            
            Circle()
                .stroke(Color.gray.opacity(0.25), lineWidth: 1.5)
                .frame(width: 200, height: 200)
            
            if UIImage(named: "shell") != nil {
                Image("shell")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .colorMultiply(shellColor)
            } else {
                Image(systemName: "egg.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
        
        // Shell title
        Text("Cracked Shell")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.white)
        
        Text("This egg didn't make it")
            .font(.system(size: 15, design: .rounded))
            .foregroundColor(.white.opacity(0.5))
        
        // Info card
        NatureCard {
            VStack(spacing: 12) {
                if let eggType = instance.eggType {
                    DetailInfoRow(icon: "oval.fill", label: "Egg Type", value: eggType.replacingOccurrences(of: "Egg", with: " Egg"))
                }
                
                DetailInfoRow(icon: "calendar", label: "Date", value: formattedDate)
                
                DetailInfoRow(icon: "mappin.circle.fill", label: "Position", value: "(\(instance.gridPosition.x), \(instance.gridPosition.y))")
            }
        }
        
        // Remove Shell button
        if removalSuccess {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                Text("Shell Removed!")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundColor(Color(hex: "#A8E6C3"))
            .padding(.vertical, 14)
            .padding(.horizontal, 32)
            .background(
                Capsule()
                    .fill(Color(hex: "#A8E6C3").opacity(0.15))
            )
            .transition(.scale.combined(with: .opacity))
        } else {
            Button {
                showRemoveConfirmation = true
            } label: {
                HStack(spacing: 10) {
                    if isRemoving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15))
                    }
                    
                    Text(removeButtonLabel)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 32)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#C0392B"), Color(hex: "#E74C3C")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color(hex: "#C0392B").opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .disabled(isRemoving)
            .opacity(isRemoving ? 0.7 : 1.0)
        }
        
        if let error = storeManager.purchaseError {
            Text(error)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.red.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    private var removeButtonLabel: String {
        if isRemoving {
            return "Purchasing..."
        }
        if let product = storeManager.removeShellProduct {
            return "Remove Shell — \(product.displayPrice)"
        }
        return "Remove Shell — £0.99"
    }
    
    private var shellColor: Color {
        if instance.eggType == "JungleEgg" {
            return Color(red: 0.341, green: 0.818, blue: 1.0)
        }
        return Color.gray
    }
    
    // MARK: - Animal Detail Content
    
    @ViewBuilder
    private var animalDetailContent: some View {
        // Large animal image
        ZStack {
            // Organic ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [rarityColor.opacity(0.15), rarityColor.opacity(0.03)],
                        center: .center,
                        startRadius: 40,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
            
            Circle()
                .stroke(rarityColor.opacity(0.25), lineWidth: 1.5)
                .frame(width: 200, height: 200)
            
            let imageName = AnimalDatabase.getImageName(for: instance.animalName)
            if let config = AnimationFrameDetector.getAnimationConfig(for: instance.animalName) {
                AnimatedSpriteView(
                    baseName: instance.animalName,
                    animationName: config.animationName,
                    frameCount: config.frameCount,
                    frameDuration: config.frameDuration,
                    startFrame: config.startFrame,
                    frameFormat: config.frameFormat
                )
                .frame(width: 140, height: 140)
            } else if UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
            } else {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        
        // Animal name
        Text(instance.animalName)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.white)
        
        // Rarity badge
        if let data = animalData {
            Text(data.rarity.rawValue.capitalized)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(rarityColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(rarityColor.opacity(0.15))
                )
                .overlay(
                    Capsule()
                        .stroke(rarityColor.opacity(0.3), lineWidth: 1)
                )
        }
        
        // Info card
        NatureCard {
            VStack(spacing: 12) {
                if let eggType = instance.eggType {
                    DetailInfoRow(icon: "oval.fill", label: "Egg", value: eggType.replacingOccurrences(of: "Egg", with: " Egg"))
                }
                
                DetailInfoRow(icon: "calendar", label: "Hatched", value: formattedDate)
                
                DetailInfoRow(icon: "mappin.circle.fill", label: "Position", value: "(\(instance.gridPosition.x), \(instance.gridPosition.y))")
            }
        }
        
        // Description
        if let data = animalData, let desc = data.description, !desc.isEmpty {
            Text(desc)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: instance.hatchDate)
    }
}

struct DetailInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#A8E6C3").opacity(0.7))
                .frame(width: 22)
            
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}
