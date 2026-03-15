//
//  CrackNotificationManager.swift
//  Fauna
//
//  Sends push notifications to friends when the user cracks an egg.
//  Uses CloudKit CKQuerySubscription on the public database to deliver
//  remote notifications, then displays them locally via UNUserNotificationCenter.
//

import Foundation
import CloudKit
import UserNotifications
import UIKit

@MainActor
final class CrackNotificationManager: ObservableObject {
    static let shared = CrackNotificationManager()
    
    // MARK: - CloudKit
    
    private let container = CKContainer(identifier: "iCloud.Cracked.CrackedSwift")
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    
    private let recordType = "EggCrackNotification"
    private let subscriptionID = "egg-crack-subscription"
    
    // Track whether we've already set up the subscription
    private let subscriptionSetupKey = "CrackNotificationSubscriptionCreated_v1"
    
    private init() {}
    
    // MARK: - Setup
    
    /// Call once on launch (after leaderboard setup so myUserID is available).
    func setup() async {
        await requestNotificationPermission()
        await ensureSubscription()
    }
    
    // MARK: - Permission
    
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("🔔 Notification permission \(granted ? "granted" : "denied")")
            
            if granted {
                // Register for remote notifications on the main thread
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            print("🔔 Notification permission error: \(error)")
        }
    }
    
    // MARK: - CloudKit Subscription
    
    /// Creates a CKQuerySubscription for EggCrackNotification records
    /// where targetUserID matches the current user. CloudKit will send a
    /// silent push whenever a matching record is created.
    private func ensureSubscription() async {
        guard let myUserID = LeaderboardManager.shared.myUserID else {
            print("🔔 No userID yet — skipping subscription setup")
            return
        }
        
        // Only create once per install
        if UserDefaults.standard.bool(forKey: subscriptionSetupKey) {
            print("🔔 Subscription already exists")
            return
        }
        
        let predicate = NSPredicate(format: "targetUserID == %@", myUserID)
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )
        
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true  // silent push — we build the local notification ourselves
        info.alertLocalizationKey = nil
        info.desiredKeys = ["crackerDisplayName", "eggType", "targetUserID"]
        subscription.notificationInfo = info
        
        do {
            try await publicDB.save(subscription)
            UserDefaults.standard.set(true, forKey: subscriptionSetupKey)
            print("🔔 CKQuerySubscription created for EggCrackNotification")
        } catch {
            // Subscription might already exist from a previous install
            print("🔔 Subscription save error (may already exist): \(error.localizedDescription)")
            UserDefaults.standard.set(true, forKey: subscriptionSetupKey)
        }
    }
    
    // MARK: - Send Crack Notifications
    
    /// Writes one EggCrackNotification record per friend to CloudKit.
    /// Each friend's subscription will fire and deliver a push.
    func notifyFriendsOfCrack(eggType: String) async {
        let leaderboard = LeaderboardManager.shared
        guard let myUserID = leaderboard.myUserID else {
            print("🔔 Can't notify — no userID")
            return
        }
        
        let displayName = AuthManager.shared.userProfile?.displayName ?? "A friend"
        let friends = leaderboard.friends
        
        guard !friends.isEmpty else {
            print("🔔 No friends to notify")
            return
        }
        
        print("🔔 Notifying \(friends.count) friends about cracked egg")
        
        // Create one record per friend
        var records: [CKRecord] = []
        for friend in friends {
            let recordID = CKRecord.ID(recordName: "crack_\(myUserID)_\(friend.friendID)_\(Int(Date().timeIntervalSince1970))")
            let record = CKRecord(recordType: recordType, recordID: recordID)
            record["crackerUserID"] = myUserID as CKRecordValue
            record["crackerDisplayName"] = displayName as CKRecordValue
            record["targetUserID"] = friend.friendID as CKRecordValue
            record["eggType"] = eggType as CKRecordValue
            record["timestamp"] = Date() as CKRecordValue
            records.append(record)
        }
        
        // Batch save — CloudKit allows up to 400 records per operation
        do {
            let result = try await publicDB.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
            print("🔔 Sent \(result.saveResults.count) crack notifications")
        } catch {
            print("🔔 Failed to send crack notifications: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Handle Incoming Push
    
    /// Called from the AppDelegate when a remote notification arrives.
    /// Fetches the new record and shows a local notification.
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) async {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        
        guard let queryNotification = notification as? CKQueryNotification,
              queryNotification.queryNotificationReason == .recordCreated else {
            return
        }
        
        // Extract info from the notification's desiredKeys
        let crackerName = queryNotification.recordFields?["crackerDisplayName"] as? String ?? "A friend"
        let eggType = queryNotification.recordFields?["eggType"] as? String ?? "their egg"
        
        // Don't notify about our own cracks
        if let crackerID = queryNotification.recordFields?["crackerUserID"] as? String,
           crackerID == LeaderboardManager.shared.myUserID {
            return
        }
        
        await showLocalNotification(crackerName: crackerName, eggType: eggType)
    }
    
    // MARK: - Local Notification Display
    
    private func showLocalNotification(crackerName: String, eggType: String) async {
        let content = UNMutableNotificationContent()
        content.title = "🥚💀 Egg Cracked!"
        content.body = "\(crackerName) just cracked \(formatEggName(eggType))! 😬"
        content.sound = .default
        content.categoryIdentifier = "EGG_CRACKED"
        
        let request = UNNotificationRequest(
            identifier: "crack_\(UUID().uuidString)",
            content: content,
            trigger: nil  // deliver immediately
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("🔔 Local notification displayed for \(crackerName)")
        } catch {
            print("🔔 Failed to show local notification: \(error)")
        }
    }
    
    /// Formats egg type names for display (e.g., "FarmEgg" → "their Farm Egg")
    private func formatEggName(_ eggType: String) -> String {
        // Convert camelCase to spaced name: "FarmEgg" → "Farm Egg"
        let spaced = eggType.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        return "their \(spaced)"
    }
    
    // MARK: - Cleanup Old Notifications
    
    /// Periodically clean up old crack notification records (older than 24h)
    /// to keep the CloudKit database tidy. Call from app launch.
    func cleanupOldNotifications() async {
        guard let myUserID = LeaderboardManager.shared.myUserID else { return }
        
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago
        let predicate = NSPredicate(format: "targetUserID == %@ AND timestamp < %@", myUserID, cutoff as NSDate)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 100)
            let idsToDelete = results.map { $0.0 }
            
            if !idsToDelete.isEmpty {
                try await publicDB.modifyRecords(saving: [], deleting: idsToDelete)
                print("🔔 Cleaned up \(idsToDelete.count) old crack notifications")
            }
        } catch {
            print("🔔 Cleanup error: \(error.localizedDescription)")
        }
    }
}
