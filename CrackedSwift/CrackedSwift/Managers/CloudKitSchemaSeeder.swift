//
//  CloudKitSchemaSeeder.swift
//  CrackedSwift
//
//  Run ONCE to create all CloudKit record types + fields in Development.
//  After running, go to CloudKit Dashboard → Schema → Indexes and add:
//
//  ┌─────────────────┬──────────────────┬────────────┬──────────┐
//  │ Record Type      │ Field            │ Queryable  │ Sortable │
//  ├─────────────────┼──────────────────┼────────────┼──────────┤
//  │ Leaderboard      │ recordName       │ ✅         │          │
//  │ Leaderboard      │ userID           │ ✅         │          │
//  │ Leaderboard      │ displayName      │ ✅         │          │
//  │ Leaderboard      │ animalsHatched   │ ✅         │ ✅       │
//  │ Leaderboard      │ totalStudyTime   │ ✅         │ ✅       │
//  │ Leaderboard      │ totalCoins       │ ✅         │ ✅       │
//  │ Leaderboard      │ currentStreak    │ ✅         │ ✅       │
//  ├─────────────────┼──────────────────┼────────────┼──────────┤
//  │ FriendRequest    │ recordName       │ ✅         │          │
//  │ FriendRequest    │ fromUserID       │ ✅         │          │
//  │ FriendRequest    │ toUserID         │ ✅         │          │
//  │ FriendRequest    │ status           │ ✅         │          │
//  ├─────────────────┼──────────────────┼────────────┼──────────┤
//  │ FriendRelation   │ recordName       │ ✅         │          │
//  │ FriendRelation   │ userID           │ ✅         │          │
//  │ FriendRelation   │ friendID         │ ✅         │          │
//  │ FriendRelation   │ friendDisplayName│ ✅         │          │
//  ├─────────────────┼──────────────────┼────────────┼──────────┤
//  │ PlayerRegistry   │ recordName       │ ✅         │          │
//  └─────────────────┴──────────────────┴────────────┴──────────┘
//
//  After adding indexes, call cleanupSeedRecords() or delete them in Dashboard.
//

import Foundation
import CloudKit

enum CloudKitSchemaSeeder {

    private static let containerID = "iCloud.Cracked.CrackedSwift"

    // Deterministic IDs so we can clean them up easily
    private static let seedLeaderboardID  = CKRecord.ID(recordName: "__seed_leaderboard")
    private static let seedFriendReqID    = CKRecord.ID(recordName: "__seed_friendrequest")
    private static let seedFriendRelID    = CKRecord.ID(recordName: "__seed_friendrelation")
    private static let seedRegistryID     = CKRecord.ID(recordName: "__seed_registry")

    /// Call this ONCE from a button or app launch.
    /// Creates dummy records that define every field CloudKit needs to see.
    static func seedSchema() async {
        let db = CKContainer(identifier: containerID).publicCloudDatabase

        // --- Leaderboard ---
        let lb = CKRecord(recordType: "Leaderboard", recordID: seedLeaderboardID)
        lb["userID"]           = "__seed" as CKRecordValue
        lb["displayName"]      = "Seed User" as CKRecordValue
        lb["animalsHatched"]   = 0 as CKRecordValue
        lb["totalStudyTime"]   = 0.0 as CKRecordValue
        lb["currentStreak"]    = 0 as CKRecordValue
        lb["totalCoins"]       = 0 as CKRecordValue
        lb["lastUpdated"]      = Date() as CKRecordValue

        // --- FriendRequest ---
        let fr = CKRecord(recordType: "FriendRequest", recordID: seedFriendReqID)
        fr["fromUserID"]       = "__seed_a" as CKRecordValue
        fr["fromDisplayName"]  = "Seed A" as CKRecordValue
        fr["toUserID"]         = "__seed_b" as CKRecordValue
        fr["toDisplayName"]    = "Seed B" as CKRecordValue
        fr["status"]           = "pending" as CKRecordValue
        fr["sentDate"]         = Date() as CKRecordValue

        // --- FriendRelation ---
        let rel = CKRecord(recordType: "FriendRelation", recordID: seedFriendRelID)
        rel["userID"]              = "__seed_a" as CKRecordValue
        rel["friendID"]            = "__seed_b" as CKRecordValue
        rel["friendDisplayName"]   = "Seed B" as CKRecordValue
        rel["since"]               = Date() as CKRecordValue

        // --- PlayerRegistry ---
        let reg = CKRecord(recordType: "PlayerRegistry", recordID: seedRegistryID)
        reg["playerIDs"] = ["__seed"] as CKRecordValue

        // Save all at once
        do {
            let result = try await db.modifyRecords(
                saving: [lb, fr, rel, reg],
                deleting: [],
                savePolicy: .allKeys
            )
            print("✅ Schema seeded! \(result.saveResults.count) records created.")
            print("👉 Now go to CloudKit Dashboard → Schema → Indexes and add the indexes listed in CloudKitSchemaSeeder.swift")
        } catch {
            print("❌ Schema seed failed: \(error)")
        }
    }

    /// Delete seed records after indexes are configured.
    static func cleanupSeedRecords() async {
        let db = CKContainer(identifier: containerID).publicCloudDatabase
        let ids = [seedLeaderboardID, seedFriendReqID, seedFriendRelID, seedRegistryID]

        do {
            let result = try await db.modifyRecords(saving: [], deleting: ids)
            print("🧹 Seed records cleaned up (\(result.deleteResults.count) deleted)")
        } catch {
            print("⚠️ Cleanup error: \(error)")
        }
    }
}
