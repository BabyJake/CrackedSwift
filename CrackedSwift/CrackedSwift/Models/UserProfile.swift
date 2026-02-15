//
//  UserProfile.swift
//  CrackedSwift
//
//  Stores the authenticated user's profile data from Sign in with Apple.
//  Apple only provides name/email on the FIRST sign-in, so we persist it.
//

import Foundation

struct UserProfile: Codable {
    /// Opaque user identifier returned by Apple (stable across sign-ins).
    let userID: String
    /// Display name assembled from the user's given + family name.
    var displayName: String?
    /// Email address (may be a private relay address).
    var email: String?
    
    // MARK: - Coding Keys
    
    enum CodingKeys: String, CodingKey {
        case userID
        case displayName
        case email
    }
    
    // MARK: - Resilient Decoder (mirrors GameData pattern)
    
    init(userID: String, displayName: String? = nil, email: String? = nil) {
        self.userID = userID
        self.displayName = displayName
        self.email = email
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID      = (try? c.decode(String.self, forKey: .userID)) ?? ""
        displayName = try? c.decode(String.self, forKey: .displayName)
        email       = try? c.decode(String.self, forKey: .email)
    }
}
