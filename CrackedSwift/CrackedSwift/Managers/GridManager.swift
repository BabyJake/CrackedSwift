//
//  GridManager.swift
//  CrackedSwift
//
//  Manages the grid layout for the sanctuary
//

import Foundation
import SwiftUI

@MainActor
class GridManager: ObservableObject {
    static let shared = GridManager()
    
    private let dataManager = GameDataManager.shared
    
    private init() {}
    
    // Grid settings
    private var gridSize: Int = 3
    private let minGridSize: Int = 3
    
    // MARK: - Drag & Drop Movement
    
    /// The id of the animal instance currently being dragged
    @Published var draggingInstanceId: String? = nil
    /// The current drag offset in grid-local screen coordinates
    @Published var dragOffset: CGSize = .zero
    /// The grid cell the dragged animal would land on (computed from drag offset)
    @Published var targetGridPosition: GameData.GridPosition? = nil
    
    private let tileWidthForCalc: CGFloat = 128
    private let tileHeightForCalc: CGFloat = 64
    
    func startDragging(_ instanceId: String) {
        draggingInstanceId = instanceId
        dragOffset = .zero
        targetGridPosition = nil
        print("🦁 Started dragging instance: \(instanceId)")
    }
    
    func updateDrag(offset: CGSize, fromPosition: GameData.GridPosition) {
        dragOffset = offset
        
        // Convert screen-space drag offset to isometric grid delta
        let dx = offset.width
        let dy = offset.height
        let gridDeltaX = Int(round((dx / (tileWidthForCalc / 2) + dy / (tileHeightForCalc / 2)) / 2))
        let gridDeltaY = Int(round((dy / (tileHeightForCalc / 2) - dx / (tileWidthForCalc / 2)) / 2))
        
        let target = GameData.GridPosition(x: fromPosition.x + gridDeltaX, y: fromPosition.y + gridDeltaY)
        
        if isPositionInGrid(target) && target != fromPosition {
            targetGridPosition = target
        } else {
            targetGridPosition = nil
        }
    }
    
    func endDrag() {
        guard let fromId = draggingInstanceId,
              let target = targetGridPosition else {
            resetDrag()
            return
        }
        
        let instances = dataManager.getAnimalInstances()
        guard instances.first(where: { $0.id == fromId }) != nil else {
            resetDrag()
            return
        }
        
        // Check if target is occupied — swap or move
        if let targetInstance = instances.first(where: { $0.gridPosition == target }) {
            swapAnimalPositions(fromId: fromId, toId: targetInstance.id)
        } else {
            moveAnimal(id: fromId, to: target)
        }
        
        resetDrag()
    }
    
    func cancelDrag() {
        resetDrag()
    }
    
    private func resetDrag() {
        draggingInstanceId = nil
        dragOffset = .zero
        targetGridPosition = nil
    }
    
    private func moveAnimal(id: String, to position: GameData.GridPosition) {
        dataManager.updateAnimalInstancePosition(id, position: position)
        dataManager.setOriginalPosition(id, position: position)
        print("🦁 ✅ Moved animal to (\(position.x), \(position.y))")
    }
    
    private func swapAnimalPositions(fromId: String, toId: String) {
        let instances = dataManager.getAnimalInstances()
        guard let fromInstance = instances.first(where: { $0.id == fromId }),
              let toInstance = instances.first(where: { $0.id == toId }) else { return }
        
        let fromPos = fromInstance.gridPosition
        let toPos = toInstance.gridPosition
        
        dataManager.updateAnimalInstancePosition(fromId, position: toPos)
        dataManager.updateAnimalInstancePosition(toId, position: fromPos)
        dataManager.setOriginalPosition(fromId, position: toPos)
        dataManager.setOriginalPosition(toId, position: fromPos)
        
        print("🦁 ✅ Swapped \(fromInstance.animalName) ↔ \(toInstance.animalName)")
    }
    
    func clearSelection() {
        resetDrag()
    }
    
    // MARK: - Grid Management
    
    func getGridSize() -> Int {
        return gridSize
    }
    
    /// - Parameter reserveSlots: Extra slots to reserve (e.g. 1 when about to add an item) so the grid is sized before placement.
    func expandGridIfNeeded(reserveSlots: Int = 0) {
        let totalItems = dataManager.getAnimalInstancesCount() + reserveSlots
        // Ensure enough blocks: need at least totalItems blocks
        // Use odd grid sizes (3,5,7...) so layout stays symmetric and we avoid crash when adding the 10th item (extra row).
        let requiredSize = Int(ceil(sqrt(Double(totalItems))))
        let oddSize = requiredSize % 2 == 0 ? requiredSize + 1 : requiredSize
        gridSize = max(minGridSize, oddSize)
    }
    
    func calculateGridSizeForItemCount(_ itemCount: Int) {
        // Calculate minimum square grid size for given item count.
        // Use odd grid sizes (3,5,7...) so layout stays symmetric and we avoid crash when adding the 10th item.
        let requiredSize = Int(ceil(sqrt(Double(itemCount))))
        let oddSize = requiredSize % 2 == 0 ? requiredSize + 1 : requiredSize
        gridSize = max(minGridSize, oddSize)
    }
    
    func getEmptyPositions(occupiedPositions: Set<GameData.GridPosition>) -> [GameData.GridPosition] {
        var emptyPositions: [GameData.GridPosition] = []
        let halfSize = gridSize / 2
        
        for x in -halfSize..<(-halfSize + gridSize) {
            for y in -halfSize..<(-halfSize + gridSize) {
                let pos = GameData.GridPosition(x: x, y: y)
                if !occupiedPositions.contains(pos) {
                    emptyPositions.append(pos)
                }
            }
        }
        
        return emptyPositions
    }
    
    func placeAnimal(_ animalName: String, hatchDate: Date, isNewlyHatched: Bool, eggType: String?) -> GameData.GridPosition? {
        while true {
            expandGridIfNeeded(reserveSlots: 1)

            let instances = dataManager.getAnimalInstances()
            let occupiedPositions = Set(instances.map { $0.gridPosition })
            let emptyPositions = getEmptyPositions(occupiedPositions: occupiedPositions)

            guard !emptyPositions.isEmpty else {
                gridSize += 1
                continue
            }

            let randomPosition = emptyPositions.randomElement()!
            let instanceId = animalName + "_" + UUID().uuidString

            let instance = GameData.AnimalInstance(
                id: instanceId,
                animalName: animalName,
                gridPosition: randomPosition,
                hatchDate: hatchDate,
                isNewlyHatched: isNewlyHatched,
                isGrave: false,
                eggType: eggType
            )

            dataManager.addAnimalInstance(instance)
            dataManager.setOriginalPosition(instanceId, position: randomPosition)

            return randomPosition
        }
    }
    
    func placeGrave(graveId: String, eggType: String, hatchDate: Date) -> GameData.GridPosition? {
        while true {
            expandGridIfNeeded(reserveSlots: 1)

            let instances = dataManager.getAnimalInstances()
            let occupiedPositions = Set(instances.map { $0.gridPosition })
            let emptyPositions = getEmptyPositions(occupiedPositions: occupiedPositions)

            guard !emptyPositions.isEmpty else {
                gridSize += 1
                continue
            }

            let randomPosition = emptyPositions.randomElement()!

            let instance = GameData.AnimalInstance(
                id: graveId,
                animalName: "Grave",
                gridPosition: randomPosition,
                hatchDate: hatchDate,
                isNewlyHatched: false,
                isGrave: true,
                eggType: eggType
            )

            dataManager.addAnimalInstance(instance)
            dataManager.setOriginalPosition(graveId, position: randomPosition)

            return randomPosition
        }
    }

    /// - Parameter skipReposition: When true, does not mutate GameDataManager (no repositioning). Use for first paint to avoid crash when swapping to sanctuary tab.
    func getVisibleInstances(for view: String, skipReposition: Bool = false) -> [GameData.AnimalInstance] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let endOfToday = calendar.date(byAdding: .day, value: 1, to: today) else {
            return dataManager.getAnimalInstances()
        }
        let instances = dataManager.getAnimalInstances()
        
        let visibleInstances: [GameData.AnimalInstance]
        
        switch view {
        case "Day":
            visibleInstances = instances.filter { calendar.isDate($0.hatchDate, inSameDayAs: today) }
        case "Week":
            guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else {
                visibleInstances = instances
                break
            }
            visibleInstances = instances.filter { $0.hatchDate >= weekStart && $0.hatchDate < endOfToday }
        case "Month":
            guard let monthStart = calendar.date(byAdding: .month, value: -1, to: today) else {
                visibleInstances = instances
                break
            }
            visibleInstances = instances.filter { $0.hatchDate >= monthStart && $0.hatchDate < endOfToday }
        case "Year":
            guard let yearStart = calendar.date(byAdding: .day, value: -364, to: today) else {
                visibleInstances = instances
                break
            }
            visibleInstances = instances.filter { $0.hatchDate >= yearStart && $0.hatchDate < endOfToday }
        default: // "All"
            visibleInstances = instances
        }
        
        // Calculate minimum grid size based on visible instances
        calculateGridSizeForItemCount(visibleInstances.count)
        
        if !skipReposition {
            repositionInstancesToFitGrid(instances: visibleInstances)
        }
        
        // Return updated instances (with corrected positions if we repositioned)
        let visibleIds = Set(visibleInstances.map { $0.id })
        return dataManager.getAnimalInstances().filter { visibleIds.contains($0.id) }
    }
    
    func reorganizeForView(_ view: String) {
        // Restore original positions first
        restoreOriginalPositions()
        
        // getVisibleInstances will calculate grid size and reposition as needed
        // No need to call it here since updateVisibleInstances will call it
    }
    
    private func restoreOriginalPositions() {
        let instances = dataManager.getAnimalInstances()
        for instance in instances {
            if let originalPos = dataManager.getOriginalPosition(instance.id) {
                dataManager.updateAnimalInstancePosition(instance.id, position: originalPos)
            }
        }
    }
    
    private func isPositionInGrid(_ position: GameData.GridPosition) -> Bool {
        let halfSize = gridSize / 2
        let minCoord = -halfSize
        let maxCoord = -halfSize + gridSize - 1
        
        return position.x >= minCoord && position.x <= maxCoord &&
               position.y >= minCoord && position.y <= maxCoord
    }
    
    private func repositionInstancesToFitGrid(instances: [GameData.AnimalInstance]) {
        let halfSize = gridSize / 2
        var occupiedPositions = Set<GameData.GridPosition>()
        
        // First, mark positions that are already in valid grid positions
        for instance in instances {
            if isPositionInGrid(instance.gridPosition) {
                occupiedPositions.insert(instance.gridPosition)
            }
        }
        
        // Reposition instances that are outside the grid
        for instance in instances {
            if !isPositionInGrid(instance.gridPosition) {
                // Find an empty position within the grid
                let emptyPositions = getEmptyPositions(occupiedPositions: occupiedPositions)
                if let newPosition = emptyPositions.first {
                    dataManager.updateAnimalInstancePosition(instance.id, position: newPosition)
                    occupiedPositions.insert(newPosition)
                } else {
                    // If no empty positions, try to find the closest valid position
                    // by clamping the coordinates
                    let minCoord = -halfSize
                    let maxCoord = -halfSize + gridSize - 1
                    let clampedX = max(minCoord, min(maxCoord, instance.gridPosition.x))
                    let clampedY = max(minCoord, min(maxCoord, instance.gridPosition.y))
                    let clampedPosition = GameData.GridPosition(x: clampedX, y: clampedY)
                    
                    // If clamped position is occupied, find nearest empty
                    if !occupiedPositions.contains(clampedPosition) {
                        dataManager.updateAnimalInstancePosition(instance.id, position: clampedPosition)
                        occupiedPositions.insert(clampedPosition)
                    } else {
                        // Find nearest empty position
                        var bestPosition: GameData.GridPosition? = nil
                        var minDistance = Int.max
                        
                        for x in -halfSize..<(-halfSize + gridSize) {
                            for y in -halfSize..<(-halfSize + gridSize) {
                                let pos = GameData.GridPosition(x: x, y: y)
                                if !occupiedPositions.contains(pos) {
                                    let distance = abs(x - instance.gridPosition.x) + abs(y - instance.gridPosition.y)
                                    if distance < minDistance {
                                        minDistance = distance
                                        bestPosition = pos
                                    }
                                }
                            }
                        }
                        
                        if let newPos = bestPosition {
                            dataManager.updateAnimalInstancePosition(instance.id, position: newPos)
                            occupiedPositions.insert(newPos)
                        }
                    }
                }
            }
        }
    }
}

