//
//  LeaderboardManager.swift
//  CrackedSwift
//
//  Manages leaderboard data and friend relationships via CloudKit.
//  Uses CKQuery with indexed fields for all fetches.
//

import Foundation
import CloudKit

@MainActor
class LeaderboardManager: ObservableObject {
    static let shared = LeaderboardManager()
    
    // MARK: - Published State
    
    @Published var globalEntries: [LeaderboardEntry] = []
    @Published var friendEntries: [LeaderboardEntry] = []
    @Published var friends: [FriendRelation] = []
    @Published var incomingRequests: [FriendRequest] = []
    @Published var outgoingRequests: [FriendRequest] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var myUserID: String?
    @Published var searchResults: [LeaderboardEntry] = []
    
    // MARK: - CloudKit
    
    private let container = CKContainer(identifier: "iCloud.Cracked.CrackedSwift")
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    
    // Record types
    private let leaderboardRecordType = "Leaderboard"
    private let friendRequestRecordType = "FriendRequest"
    private let friendRelationRecordType = "FriendRelation"
    
    // Field names
    private let userIDField = "userID"
    private let displayNameField = "displayName"
    private let animalsHatchedField = "animalsHatched"
    private let totalStudyTimeField = "totalStudyTime"
    private let currentStreakField = "currentStreak"
    private let totalCoinsField = "totalCoins"
    private let lastUpdatedField = "lastUpdated"
    
    // UserDefaults
    private let userIDKey = "LeaderboardUserID"
    
    /// Serial queue to prevent concurrent pushStats race conditions
    private var pushTask: Task<Void, Never>?
    private var pushDebounceTask: Task<Void, Never>?
    
    private init() {
        myUserID = UserDefaults.standard.string(forKey: userIDKey)
    }
    
    // MARK: - Deterministic Record IDs (for save/update without querying first)
    
    private func leaderboardRecordID(for userID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "lb_\(userID)")
    }
    
    private func friendRelationRecordID(from userID: String, to friendID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "fr_\(userID)_\(friendID)")
    }
    
    private func friendRequestRecordID(from senderID: String, to targetID: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "req_\(senderID)_\(targetID)")
    }
    
    // MARK: - Setup
    
    func setup() async {
        guard myUserID == nil else {
            await pushStats()
            await refreshAll()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let recordID = try await container.userRecordID()
            let userID = recordID.recordName
            myUserID = userID
            UserDefaults.standard.set(userID, forKey: userIDKey)
            
            print("[Leaderboard] Setup: userID = \(userID)")
            
            await pushStats()
            await refreshAll()
            
        } catch {
            errorMessage = "Failed to connect to iCloud: \(error.localizedDescription)"
            print("[Leaderboard] Setup error: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshAll() async {
        isLoading = true
        async let g: () = fetchGlobalLeaderboard()
        async let f: () = fetchFriends()
        async let ir: () = fetchIncomingRequests()
        async let or_: () = fetchOutgoingRequests()
        _ = await (g, f, ir, or_)
        await fetchFriendLeaderboard()
        isLoading = false
    }
    
    // MARK: - Build Local Entry (fallback)
    
    private func buildLocalEntry() -> LeaderboardEntry? {
        guard let userID = myUserID else { return nil }
        let gameData = GameDataManager.shared
        let profile = AuthManager.shared.userProfile
        let displayName = profile?.displayName ?? "Player"
        
        let placedCount = gameData.getAnimalInstances().filter { !$0.isGrave }.count
        let pendingCount = gameData.getPendingAnimals().count
        
        return LeaderboardEntry(
            id: userID,
            displayName: displayName,
            animalsHatched: placedCount + pendingCount,
            totalStudyTime: gameData.getTotalStudyTime(),
            currentStreak: gameData.getCurrentStreak(),
            totalCoins: gameData.getTotalCoins(),
            lastUpdated: Date()
        )
    }
    
    // MARK: - Push Stats
    
    func pushStats() async {
        pushDebounceTask?.cancel()
        
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await self?.executePushStats()
            return
        }
        pushDebounceTask = task
        await task.value
    }
    
    private func executePushStats() async {
        await pushTask?.value
        
        let task = Task { [weak self] in
            await self?.performPush()
            return
        }
        pushTask = task
        await task.value
    }
    
    private func performPush() async {
        guard let userID = myUserID else {
            print("[Leaderboard] performPush: No userID")
            return
        }
        
        let gameData = GameDataManager.shared
        let profile = AuthManager.shared.userProfile
        let displayName = profile?.displayName ?? "Player"
        
        let placedCount = gameData.getAnimalInstances().filter { !$0.isGrave }.count
        let pendingCount = gameData.getPendingAnimals().count
        let animalCount = placedCount + pendingCount
        
        print("[Leaderboard] performPush: \(displayName) — animals:\(animalCount) study:\(gameData.getTotalStudyTime()) streak:\(gameData.getCurrentStreak()) coins:\(gameData.getTotalCoins())")
        
        let recordID = leaderboardRecordID(for: userID)
        
        do {
            let record: CKRecord
            do {
                record = try await publicDB.record(for: recordID)
            } catch {
                let newRecord = CKRecord(recordType: leaderboardRecordType, recordID: recordID)
                newRecord[userIDField] = userID as NSString
                record = newRecord
            }
            
            record[displayNameField] = displayName as NSString
            record[animalsHatchedField] = animalCount as NSNumber
            record[totalStudyTimeField] = gameData.getTotalStudyTime() as NSNumber
            record[currentStreakField] = gameData.getCurrentStreak() as NSNumber
            record[totalCoinsField] = gameData.getTotalCoins() as NSNumber
            record[lastUpdatedField] = Date() as NSDate
            
            try await publicDB.save(record)
            print("[Leaderboard] ✅ Stats pushed")
            
            await fetchGlobalLeaderboard()
            await fetchFriendLeaderboard()
            
        } catch {
            print("[Leaderboard] ❌ Push failed: \(error)")
            injectLocalEntryIfMissing()
        }
    }
    
    private func injectLocalEntryIfMissing() {
        guard let entry = buildLocalEntry() else { return }
        if !globalEntries.contains(where: { $0.id == entry.id }) {
            globalEntries.append(entry)
            globalEntries.sort { $0.animalsHatched > $1.animalsHatched }
        }
        if !friendEntries.contains(where: { $0.id == entry.id }) {
            friendEntries.append(entry)
            friendEntries.sort { $0.animalsHatched > $1.animalsHatched }
        }
    }
    
    // MARK: - Fetch Global Leaderboard (CKQuery — all players)
    
    func fetchGlobalLeaderboard() async {
        let query = CKQuery(recordType: leaderboardRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: animalsHatchedField, ascending: false)]
        
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 100)
            
            var entries: [LeaderboardEntry] = []
            for (_, result) in results {
                if let record = try? result.get() {
                    entries.append(leaderboardEntry(from: record))
                }
            }
            
            // Ensure local user is present with freshest data
            if let local = buildLocalEntry() {
                if let idx = entries.firstIndex(where: { $0.id == local.id }) {
                    entries[idx] = local
                } else {
                    entries.append(local)
                }
            }
            
            entries.sort { $0.animalsHatched > $1.animalsHatched }
            globalEntries = entries
            
            print("[Leaderboard] 📊 Global: \(globalEntries.count) entries")
            
        } catch {
            print("[Leaderboard] ❌ fetchGlobalLeaderboard: \(error)")
            injectLocalEntryIfMissing()
        }
    }
    
    // MARK: - Fetch Friend Leaderboard (CKQuery by userID IN friendIDs)
    
    func fetchFriendLeaderboard() async {
        guard let userID = myUserID else { return }
        
        var friendIDs = friends.map { $0.friendID }
        friendIDs.append(userID)
        
        let predicate = NSPredicate(format: "userID IN %@", friendIDs)
        let query = CKQuery(recordType: leaderboardRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: animalsHatchedField, ascending: false)]
        
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 100)
            
            var entries: [LeaderboardEntry] = []
            for (_, result) in results {
                if let record = try? result.get() {
                    entries.append(leaderboardEntry(from: record))
                }
            }
            
            if let local = buildLocalEntry() {
                if let idx = entries.firstIndex(where: { $0.id == local.id }) {
                    entries[idx] = local
                } else {
                    entries.append(local)
                }
            }
            
            entries.sort { $0.animalsHatched > $1.animalsHatched }
            friendEntries = entries
            
            print("[Leaderboard] 👥 Friends: \(friendEntries.count) entries")
            
        } catch {
            print("[Leaderboard] ❌ fetchFriendLeaderboard: \(error)")
        }
    }
    
    // MARK: - Friend Requests
    
    func sendFriendRequest(username: String) async -> Bool {
        guard let userID = myUserID else {
            errorMessage = "Not signed in to iCloud"
            return false
        }
        
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let (targetID, targetName) = await lookupUserByUsername(trimmed) else {
            errorMessage = "No player found named \"\(trimmed)\""
            return false
        }
        
        if targetID == userID {
            errorMessage = "You can't add yourself!"
            return false
        }
        
        if friends.contains(where: { $0.friendID == targetID }) {
            errorMessage = "You're already friends with \(targetName)!"
            return false
        }
        
        if outgoingRequests.contains(where: { $0.toUserID == targetID && $0.status == .pending }) {
            errorMessage = "Request already sent to \(targetName)"
            return false
        }
        
        return await saveFriendRequest(from: userID, to: targetID, targetName: targetName)
    }
    
    func sendFriendRequestToUser(targetID: String, targetName: String) async -> Bool {
        guard let userID = myUserID else {
            errorMessage = "Not signed in to iCloud"
            return false
        }
        
        if targetID == userID {
            errorMessage = "You can't add yourself!"
            return false
        }
        
        if friends.contains(where: { $0.friendID == targetID }) {
            errorMessage = "You're already friends with \(targetName)!"
            return false
        }
        
        return await saveFriendRequest(from: userID, to: targetID, targetName: targetName)
    }
    
    private func saveFriendRequest(from userID: String, to targetID: String, targetName: String) async -> Bool {
        let displayName = AuthManager.shared.userProfile?.displayName ?? "Player"
        let reqRecordID = friendRequestRecordID(from: userID, to: targetID)
        
        let record = CKRecord(recordType: friendRequestRecordType, recordID: reqRecordID)
        record["fromUserID"] = userID as NSString
        record["fromDisplayName"] = displayName as NSString
        record["toUserID"] = targetID as NSString
        record["toDisplayName"] = targetName as NSString
        record["status"] = FriendRequest.FriendRequestStatus.pending.rawValue as NSString
        record["sentDate"] = Date() as NSDate
        
        do {
            try await publicDB.save(record)
            print("[Leaderboard] Friend request sent to \(targetName)")
            await fetchOutgoingRequests()
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Failed to send request: \(error.localizedDescription)"
            return false
        }
    }
    
    func acceptFriendRequest(_ request: FriendRequest) async {
        guard let userID = myUserID else { return }
        
        do {
            // Update request status
            let reqRecordID = friendRequestRecordID(from: request.fromUserID, to: userID)
            do {
                let reqRecord = try await publicDB.record(for: reqRecordID)
                reqRecord["status"] = FriendRequest.FriendRequestStatus.accepted.rawValue as NSString
                try await publicDB.save(reqRecord)
            } catch {
                print("[Leaderboard] Could not update request record: \(error)")
            }
            
            // Create bidirectional friend relations
            let myDisplayName = AuthManager.shared.userProfile?.displayName ?? "Player"
            
            let rel1ID = friendRelationRecordID(from: userID, to: request.fromUserID)
            let relation1 = CKRecord(recordType: friendRelationRecordType, recordID: rel1ID)
            relation1["userID"] = userID as NSString
            relation1["friendID"] = request.fromUserID as NSString
            relation1["friendDisplayName"] = request.fromDisplayName as NSString
            relation1["since"] = Date() as NSDate
            
            let rel2ID = friendRelationRecordID(from: request.fromUserID, to: userID)
            let relation2 = CKRecord(recordType: friendRelationRecordType, recordID: rel2ID)
            relation2["userID"] = request.fromUserID as NSString
            relation2["friendID"] = userID as NSString
            relation2["friendDisplayName"] = myDisplayName as NSString
            relation2["since"] = Date() as NSDate
            
            try await publicDB.modifyRecords(saving: [relation1, relation2], deleting: [])
            print("[Leaderboard] Accepted friend request from \(request.fromDisplayName)")
            
            await fetchFriends()
            await fetchIncomingRequests()
            
        } catch {
            print("[Leaderboard] Failed to accept request: \(error)")
        }
    }
    
    func declineFriendRequest(_ request: FriendRequest) async {
        guard let userID = myUserID else { return }
        
        let reqRecordID = friendRequestRecordID(from: request.fromUserID, to: userID)
        
        do {
            let record = try await publicDB.record(for: reqRecordID)
            record["status"] = FriendRequest.FriendRequestStatus.declined.rawValue as NSString
            try await publicDB.save(record)
            incomingRequests.removeAll { $0.fromUserID == request.fromUserID }
        } catch {
            print("[Leaderboard] Failed to decline request: \(error)")
        }
    }
    
    func removeFriend(_ friend: FriendRelation) async {
        guard let userID = myUserID else { return }
        
        let rel1ID = friendRelationRecordID(from: userID, to: friend.friendID)
        let rel2ID = friendRelationRecordID(from: friend.friendID, to: userID)
        
        do {
            try await publicDB.modifyRecords(saving: [], deleting: [rel1ID, rel2ID])
            friends.removeAll { $0.friendID == friend.friendID }
            print("[Leaderboard] Removed friend \(friend.friendDisplayName)")
        } catch {
            print("[Leaderboard] Failed to remove friend: \(error)")
        }
    }
    
    // MARK: - Fetch Friends (CKQuery)
    
    func fetchFriends() async {
        guard let userID = myUserID else { return }
        
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: friendRelationRecordType, predicate: predicate)
        
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 100)
            
            var relations: [FriendRelation] = []
            for (recordID, result) in results {
                if let record = try? result.get() {
                    let relation = FriendRelation(
                        id: recordID.recordName,
                        userID: record["userID"] as? String ?? userID,
                        friendID: record["friendID"] as? String ?? "",
                        friendDisplayName: record["friendDisplayName"] as? String ?? "Unknown",
                        since: record["since"] as? Date ?? Date()
                    )
                    relations.append(relation)
                }
            }
            
            friends = relations
            print("[Leaderboard] Fetched \(friends.count) friends")
            
        } catch {
            print("[Leaderboard] Failed to fetch friends: \(error)")
        }
    }
    
    // MARK: - Fetch Incoming Requests (CKQuery)
    
    func fetchIncomingRequests() async {
        guard let userID = myUserID else { return }
        
        let predicate = NSPredicate(format: "toUserID == %@ AND status == %@", userID, FriendRequest.FriendRequestStatus.pending.rawValue)
        let query = CKQuery(recordType: friendRequestRecordType, predicate: predicate)
        
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 50)
            
            var requests: [FriendRequest] = []
            for (recordID, result) in results {
                if let record = try? result.get() {
                    requests.append(FriendRequest(
                        id: recordID.recordName,
                        fromUserID: record["fromUserID"] as? String ?? "",
                        fromDisplayName: record["fromDisplayName"] as? String ?? "Unknown",
                        toUserID: record["toUserID"] as? String ?? "",
                        status: .pending,
                        sentDate: record["sentDate"] as? Date ?? Date()
                    ))
                }
            }
            
            incomingRequests = requests
            print("[Leaderboard] Fetched \(incomingRequests.count) incoming requests")
            
        } catch {
            print("[Leaderboard] Failed to fetch incoming requests: \(error)")
        }
    }
    
    // MARK: - Fetch Outgoing Requests (CKQuery)
    
    func fetchOutgoingRequests() async {
        guard let userID = myUserID else { return }
        
        let predicate = NSPredicate(format: "fromUserID == %@ AND status == %@", userID, FriendRequest.FriendRequestStatus.pending.rawValue)
        let query = CKQuery(recordType: friendRequestRecordType, predicate: predicate)
        
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 50)
            
            var requests: [FriendRequest] = []
            for (recordID, result) in results {
                if let record = try? result.get() {
                    requests.append(FriendRequest(
                        id: recordID.recordName,
                        fromUserID: record["fromUserID"] as? String ?? "",
                        fromDisplayName: record["fromDisplayName"] as? String ?? "Unknown",
                        toUserID: record["toUserID"] as? String ?? "",
                        status: .pending,
                        sentDate: record["sentDate"] as? Date ?? Date()
                    ))
                }
            }
            
            outgoingRequests = requests
            print("[Leaderboard] Fetched \(outgoingRequests.count) outgoing requests")
            
        } catch {
            print("[Leaderboard] Failed to fetch outgoing requests: \(error)")
        }
    }
    
    // MARK: - Search / Lookup (CKQuery)
    
    func searchUsers(query searchText: String) async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
        
        let predicate = NSPredicate(format: "displayName BEGINSWITH[c] %@", trimmed)
        let query = CKQuery(recordType: leaderboardRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: displayNameField, ascending: true)]
        
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 20)
            
            var entries: [LeaderboardEntry] = []
            for (_, result) in results {
                if let record = try? result.get() {
                    let entry = leaderboardEntry(from: record)
                    if entry.id != myUserID {
                        entries.append(entry)
                    }
                }
            }
            
            searchResults = entries
            
        } catch {
            print("[Leaderboard] Search failed: \(error)")
            searchResults = []
        }
    }
    
    private func lookupUserByUsername(_ username: String) async -> (String, String)? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let predicate = NSPredicate(format: "displayName ==[c] %@", trimmed)
        let query = CKQuery(recordType: leaderboardRecordType, predicate: predicate)
        
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            for (_, result) in results {
                if let record = try? result.get(),
                   let uid = record[userIDField] as? String,
                   let name = record[displayNameField] as? String {
                    return (uid, name)
                }
            }
        } catch {
            print("[Leaderboard] Lookup failed: \(error)")
        }
        return nil
    }
    
    // MARK: - Helpers
    
    private func safeInt(_ value: Any?) -> Int {
        if let i = value as? Int { return i }
        if let i = value as? Int64 { return Int(i) }
        if let i = value as? Int32 { return Int(i) }
        if let n = value as? NSNumber { return n.intValue }
        return 0
    }
    
    private func safeDouble(_ value: Any?) -> Double {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let i = value as? Int64 { return Double(i) }
        if let n = value as? NSNumber { return n.doubleValue }
        return 0.0
    }
    
    private func leaderboardEntry(from record: CKRecord) -> LeaderboardEntry {
        let userID = record[userIDField] as? String ?? record.recordID.recordName
        let displayName = record[displayNameField] as? String ?? "Unknown"
        let animalsHatched = safeInt(record[animalsHatchedField])
        let totalStudyTime = safeDouble(record[totalStudyTimeField])
        let currentStreak = safeInt(record[currentStreakField])
        let totalCoins = safeInt(record[totalCoinsField])
        let lastUpdated = record[lastUpdatedField] as? Date ?? Date()
        
        return LeaderboardEntry(
            id: userID,
            displayName: displayName,
            animalsHatched: animalsHatched,
            totalStudyTime: totalStudyTime,
            currentStreak: currentStreak,
            totalCoins: totalCoins,
            lastUpdated: lastUpdated
        )
    }
    
    func sortedEntries(_ entries: [LeaderboardEntry], by category: LeaderboardCategory) -> [LeaderboardEntry] {
        switch category {
        case .animalsHatched:
            return entries.sorted { $0.animalsHatched > $1.animalsHatched }
        case .studyTime:
            return entries.sorted { $0.totalStudyTime > $1.totalStudyTime }
        case .streak:
            return entries.sorted { $0.currentStreak > $1.currentStreak }
        case .coins:
            return entries.sorted { $0.totalCoins > $1.totalCoins }
        }
    }
    
    func valueString(for entry: LeaderboardEntry, category: LeaderboardCategory) -> String {
        switch category {
        case .animalsHatched:
            return "\(entry.animalsHatched)"
        case .studyTime:
            return entry.formattedStudyTime
        case .streak:
            return "\(entry.currentStreak) days"
        case .coins:
            return "\(entry.totalCoins)"
        }
    }
}