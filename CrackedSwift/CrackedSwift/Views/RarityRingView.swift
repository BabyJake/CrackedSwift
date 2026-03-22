//
//  RarityRingView.swift
//  Fauna
//
//  Displays rarity spawn chances as colored arc segments around the timer.
//  Updates dynamically as the user changes study duration.
//

import SwiftUI

struct RarityRingView: View {
    let distribution: [RarityTierChance]
    var diameter: CGFloat = 308
    var strokeWidth: CGFloat = 12
    
    private let gapSize: Double = 0.005 // ~1.8° gap between segments
    
    var body: some View {
        let segments = computeSegments()
        
        ZStack {
            // Subtle background track
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: strokeWidth)
                .frame(width: diameter, height: diameter)
            
            // Rarity arc segments
            ForEach(0..<segments.count, id: \.self) { index in
                let segment = segments[index]
                
                if segment.end - segment.start > 0.001 {
                    Circle()
                        .trim(from: segment.start, to: segment.end)
                        .stroke(
                            segmentColor(for: segment.rarity),
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt)
                        )
                        .frame(width: diameter, height: diameter)
                        .rotationEffect(.degrees(-90))
                        .shadow(
                            color: glowColor(for: segment.rarity),
                            radius: glowRadius(for: segment.rarity)
                        )
                }
            }
        }
        .frame(width: diameter + strokeWidth, height: diameter + strokeWidth)
        .animation(.easeInOut(duration: 0.4), value: distribution)
    }
    
    // MARK: - Segment Colors
    
    private func segmentColor(for rarity: AnimalRarity) -> Color {
        AppColors.color(for: rarity).opacity(0.9)
    }
    
    /// Legendary and mythic segments get a subtle glow
    private func glowColor(for rarity: AnimalRarity) -> Color {
        switch rarity {
        case .legendary: return Color.yellow.opacity(0.35)
        case .mythic:    return Color.orange.opacity(0.45)
        default:         return .clear
        }
    }
    
    private func glowRadius(for rarity: AnimalRarity) -> CGFloat {
        switch rarity {
        case .legendary: return 4
        case .mythic:    return 6
        default:         return 0
        }
    }
    
    // MARK: - Segment Geometry
    
    private struct SegmentData {
        let rarity: AnimalRarity
        let start: Double
        let end: Double
    }
    
    private func computeSegments() -> [SegmentData] {
        let nonZero = distribution.filter { $0.percentage > 0.001 }
        guard !nonZero.isEmpty else { return [] }
        
        let gapCount = nonZero.count
        let totalGap = gapSize * Double(gapCount)
        let fillSpace = max(0.01, 1.0 - totalGap)
        
        var result: [SegmentData] = []
        var position: Double = gapSize / 2
        
        // Build segments for all 6 rarities; zero-percentage ones collapse to zero width
        for item in distribution {
            if item.percentage > 0.001 {
                let size = item.percentage * fillSpace
                result.append(SegmentData(rarity: item.rarity, start: position, end: position + size))
                position += size + gapSize
            } else {
                // Collapsed segment (keeps stable index for animation)
                result.append(SegmentData(rarity: item.rarity, start: position, end: position))
            }
        }
        
        return result
    }
}

// MARK: - Compact Rarity Legend

struct RarityLegendView: View {
    let distribution: [RarityTierChance]
    
    var body: some View {
        // Two-row layout: common/uncommon/rare on top, epic/legendary/mythic on bottom
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                ForEach(distribution.prefix(3), id: \.rarity) { item in
                    legendItem(item)
                }
            }
            HStack(spacing: 12) {
                ForEach(distribution.dropFirst(3), id: \.rarity) { item in
                    legendItem(item)
                }
            }
        }
    }
    
    @ViewBuilder
    private func legendItem(_ item: RarityTierChance) -> some View {
        if item.percentage > 0.001 {
            HStack(spacing: 4) {
                Circle()
                    .fill(AppColors.color(for: item.rarity))
                    .frame(width: 8, height: 8)
                
                Text(abbreviatedName(item.rarity))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                Text(formatPercentage(item.percentage))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }
    
    private func abbreviatedName(_ rarity: AnimalRarity) -> String {
        switch rarity {
        case .common:    return "C"
        case .uncommon:  return "U"
        case .rare:      return "R"
        case .epic:      return "E"
        case .legendary: return "L"
        case .mythic:    return "M"
        }
    }
    
    private func formatPercentage(_ value: Double) -> String {
        let pct = value * 100
        if pct >= 10 {
            return String(format: "%.0f%%", pct)
        } else if pct >= 1 {
            return String(format: "%.1f%%", pct)
        } else {
            return String(format: "%.1f%%", pct)
        }
    }
}

#Preview {
    ZStack {
        AppColors.backgroundGreen
            .ignoresSafeArea()
        
        VStack(spacing: 16) {
            RarityRingView(distribution: [
                RarityTierChance(rarity: .common, percentage: 0.40),
                RarityTierChance(rarity: .uncommon, percentage: 0.25),
                RarityTierChance(rarity: .rare, percentage: 0.20),
                RarityTierChance(rarity: .epic, percentage: 0.10),
                RarityTierChance(rarity: .legendary, percentage: 0.04),
                RarityTierChance(rarity: .mythic, percentage: 0.005)
            ])
            
            RarityLegendView(distribution: [
                RarityTierChance(rarity: .common, percentage: 0.40),
                RarityTierChance(rarity: .uncommon, percentage: 0.25),
                RarityTierChance(rarity: .rare, percentage: 0.20),
                RarityTierChance(rarity: .epic, percentage: 0.10),
                RarityTierChance(rarity: .legendary, percentage: 0.04),
                RarityTierChance(rarity: .mythic, percentage: 0.005)
            ])
        }
    }
}
