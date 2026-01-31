//
//  DesignSystem.swift
//  CrackedSwift
//
//  Shared design tokens and utilities
//

import SwiftUI

// MARK: - Colors
struct AppColors {
    static let backgroundGreen = Color(hex: "#3D7A5F")
    static let buttonGreen = Color(hex: "#6ECB9B")
    static let coinGold = Color(hex: "#C79F4F")
    static let coinBrown = Color(hex: "#8B6B3B")
    static let eggBeige = Color(hex: "#E0C9A6")
    static let circleGreen1 = Color(hex: "#B2D8B2")
    static let circleBeige = Color(hex: "#DDCBA6")
    static let circleGreen2 = Color(hex: "#A6B29B")
    
    // Rarity colors (for hatched animal name, sanctuary, etc.)
    static let rarityCommon = Color.gray
    static let rarityUncommon = Color.green
    static let rarityRare = Color.blue
    static let rarityEpic = Color.purple
    static let rarityLegendary = Color.yellow
    static let rarityMythic = Color.orange
    
    static func color(for rarity: AnimalRarity) -> Color {
        switch rarity {
        case .common: return rarityCommon
        case .uncommon: return rarityUncommon
        case .rare: return rarityRare
        case .epic: return rarityEpic
        case .legendary: return rarityLegendary
        case .mythic: return rarityMythic
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}



