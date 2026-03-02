//
//  LeaderboardEntry.swift
//  CrackedSwift
//
//  Models for leaderboard and friend system
//

import Foundation

struct LeaderboardEntry: Identifiable, Codable {
    let id: String // CloudKit record ID or user ID
    let displayName: String
    let animalsHatched: Int
    let totalStudyTime: TimeInterval // seconds
    let currentStreak: Int
    let totalCoins: Int
    let lastUpdated: Date
    
    var formattedStudyTime: String {
        let hours = Int(totalStudyTime) / 3600
        let minutes = (Int(totalStudyTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var rankBadge: String {
        if animalsHatched >= 100 { return "🏆" }
        if animalsHatched >= 50 { return "🥇" }
        if animalsHatched >= 25 { return "🥈" }
        if animalsHatched >= 10 { return "🥉" }
        return "🥚"
    }
}

struct FriendRequest: Identifiable, Codable {
    let id: String
    let fromUserID: String
    let fromDisplayName: String
    let toUserID: String
    let status: FriendRequestStatus
    let sentDate: Date
    
    enum FriendRequestStatus: String, Codable {
        case pending
        case accepted
        case declined
    }
}

struct FriendRelation: Identifiable, Codable {
    let id: String
    let userID: String
    let friendID: String
    let friendDisplayName: String
    let since: Date
}

enum LeaderboardCategory: String, CaseIterable, Identifiable {
    case animalsHatched = "Animals Hatched"
    case studyTime = "Study Time"
    case streak = "Current Streak"
    case coins = "Total Coins"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .animalsHatched: return "pawprint.fill"
        case .studyTime: return "clock.fill"
        case .streak: return "flame.fill"
        case .coins: return "circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .animalsHatched: return "green"
        case .studyTime: return "blue"
        case .streak: return "orange"
        case .coins: return "yellow"
        }
    }
}

enum LeaderboardScope: String, CaseIterable, Identifiable {
    case global = "Global"
    case friends = "Friends"
    
    var id: String { rawValue }
}