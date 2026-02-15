//
//  CloudKitManager.swift
//  CrackedSwift
//
//  Syncs GameData to iCloud via CloudKit PUBLIC database.
//  The public database uses the APP's quota (provided by Apple), not the user's
//  iCloud storage — so it works even if the user's iCloud is full.
//
//  Each user's save is keyed by their unique CloudKit user record ID.
//
//  Strategy:
//  - Store the entire GameData as a single JSON blob in a CKRecord.
//  - Debounce saves so rapid mutations don't flood CloudKit.
//  - On fetch, look up the record by the user's unique ID.
//

import Foundation
import CloudKit

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    // MARK: - Published State
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced
        case error(String)
    }
    
    @Published private(set) var syncStatus: SyncStatus = .idle
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var iCloudAvailable: Bool = false
    
    // MARK: - CloudKit Config
    
    private let container = CKContainer(identifier: "iCloud.Cracked.CrackedSwift")
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    
    private let recordType = "GameSave"
    private let gameDataField = "gameDataJSON"
    private let lastModifiedField = "lastModified"
    private let ownerField = "ownerID" // stores the user record name for querying
    
    // Summary fields — visible as columns in CloudKit Dashboard
    private let displayNameField = "displayName"
    private let totalCoinsField = "totalCoins"
    private let animalCountField = "animalCount"
    private let currentStreakField = "currentStreak"
    private let totalStudyTimeField = "totalStudyTime"
    private let eggCountField = "eggCount"
    
    // The user's unique CloudKit record name (fetched once on launch)
    private var userRecordName: String?
    
    // MARK: - Debounce
    
    private var debounceTask: Task<Void, Never>?
    
    // MARK: - Init
    
    private init() {
        // iCloud status will be checked in syncOnLaunch() before any operations
    }
    
    // MARK: - iCloud Status
    
    /// Awaitable iCloud status check. Must be called before any CloudKit operations.
    func refreshiCloudStatus() async {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                self.iCloudAvailable = true
            case .noAccount, .restricted, .couldNotDetermine, .temporarilyUnavailable:
                self.iCloudAvailable = false
            @unknown default:
                self.iCloudAvailable = false
            }
        } catch {
            self.iCloudAvailable = false
            print("[CloudKit] Account status error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - User Identity
    
    /// Fetches the current user's CloudKit record name (unique per iCloud account).
    /// This is used to key the save record so each user has their own save in the public DB.
    private func ensureUserRecordName() async -> String? {
        if let existing = userRecordName {
            return existing
        }
        
        do {
            let userRecordID = try await container.userRecordID()
            self.userRecordName = userRecordID.recordName
            return userRecordID.recordName
        } catch {
            print("[CloudKit] Failed to fetch user record ID: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Builds a deterministic record ID from the user's unique CloudKit identity.
    private func recordID(for userRecordName: String) -> CKRecord.ID {
        return CKRecord.ID(recordName: "save_\(userRecordName)")
    }
    
    // MARK: - Save (Debounced)
    
    /// Schedule a debounced save of GameData to CloudKit.
    /// Call this after every local save — rapid calls are coalesced.
    func scheduleSave(gameData: GameData) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(3_000_000_000)) // 3 seconds
            guard !Task.isCancelled else { return }
            await self?.pushToCloud(gameData: gameData)
        }
    }
    
    /// Immediately push GameData to CloudKit (bypasses debounce).
    func saveNow(gameData: GameData) async {
        debounceTask?.cancel()
        await pushToCloud(gameData: gameData)
    }
    
    // MARK: - Push
    
    private func pushToCloud(gameData: GameData, retryCount: Int = 0) async {
        // Refresh status if we haven't confirmed availability yet
        if !iCloudAvailable { await refreshiCloudStatus() }
        guard iCloudAvailable else {
            print("[CloudKit] iCloud not available — skipping push")
            return
        }
        
        guard let userName = await ensureUserRecordName() else {
            syncStatus = .error("Could not identify iCloud account.")
            return
        }
        
        syncStatus = .syncing
        
        let recID = recordID(for: userName)
        
        do {
            let jsonData = try JSONEncoder().encode(gameData)
            
            // Try to fetch existing record to update it (avoids "server record changed" errors)
            let record: CKRecord
            do {
                record = try await publicDB.record(for: recID)
            } catch {
                // Record doesn't exist yet — create a new one
                record = CKRecord(recordType: recordType, recordID: recID)
                // Tag with owner ID so we can query by it if needed
                record[ownerField] = userName as NSString
            }
            
            record[gameDataField] = jsonData as NSData
            record[lastModifiedField] = Date() as NSDate
            
            // Write summary fields so they're visible as columns in CloudKit Dashboard
            let profile = AuthManager.shared.userProfile
            record[displayNameField] = (profile?.displayName ?? "Unknown") as NSString
            record[totalCoinsField] = gameData.totalCoins as NSNumber
            record[animalCountField] = gameData.animalInstances.count as NSNumber
            record[currentStreakField] = gameData.currentStreak as NSNumber
            record[totalStudyTimeField] = gameData.totalStudyTime as NSNumber
            record[eggCountField] = gameData.purchasedEggs.values.reduce(0, +) as NSNumber
            
            try await publicDB.save(record)
            
            lastSyncDate = Date()
            syncStatus = .synced
            
            // Persist last sync date locally
            UserDefaults.standard.set(lastSyncDate, forKey: "CloudKitLastSyncDate")
            
            print("[CloudKit] Push succeeded (public DB)")
        } catch let ckError as CKError {
            let friendly = friendlyErrorMessage(for: ckError)
            
            // Retry on transient errors (up to 3 attempts)
            if retryCount < 3 && isRetryableError(ckError) {
                let delay = UInt64(pow(2.0, Double(retryCount))) * 1_000_000_000
                print("[CloudKit] Retrying push in \(pow(2.0, Double(retryCount)))s (attempt \(retryCount + 1)/3)")
                try? await Task.sleep(nanoseconds: delay)
                await pushToCloud(gameData: gameData, retryCount: retryCount + 1)
                return
            }
            
            syncStatus = .error(friendly)
            print("[CloudKit] Push failed: \(ckError.localizedDescription)")
        } catch {
            syncStatus = .error(error.localizedDescription)
            print("[CloudKit] Push failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Helpers
    
    private func isRetryableError(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy, .serverResponseLost:
            return true
        default:
            return false
        }
    }
    
    private func friendlyErrorMessage(for error: CKError) -> String {
        switch error.code {
        case .quotaExceeded:
            return "Cloud storage temporarily unavailable. Try again later."
        case .networkUnavailable, .networkFailure:
            return "No internet connection. Will retry when online."
        case .notAuthenticated:
            return "Not signed in to iCloud. Go to Settings > [Your Name] to sign in."
        case .serviceUnavailable, .serverResponseLost:
            return "iCloud is temporarily unavailable. Try again later."
        case .requestRateLimited:
            return "Too many requests. Will retry shortly."
        case .incompatibleVersion:
            return "Please update the app to sync with iCloud."
        case .serverRecordChanged:
            return "Cloud save was updated elsewhere. Tap Restore to get the latest."
        default:
            return error.localizedDescription
        }
    }
    
    // MARK: - Fetch
    
    /// Fetch GameData from CloudKit. Returns nil if no cloud save exists.
    func fetchFromCloud() async -> GameData? {
        if !iCloudAvailable { await refreshiCloudStatus() }
        guard iCloudAvailable else {
            print("[CloudKit] iCloud not available — skipping fetch")
            syncStatus = .error("iCloud not available")
            return nil
        }
        
        guard let userName = await ensureUserRecordName() else {
            syncStatus = .error("Could not identify iCloud account.")
            return nil
        }
        
        syncStatus = .syncing
        
        let recID = recordID(for: userName)
        
        do {
            let record = try await publicDB.record(for: recID)
            
            guard let jsonData = record[gameDataField] as? Data else {
                print("[CloudKit] Record found but no game data field")
                syncStatus = .error("Cloud save is empty")
                return nil
            }
            
            let cloudGameData = try JSONDecoder().decode(GameData.self, from: jsonData)
            
            lastSyncDate = record[lastModifiedField] as? Date ?? record.modificationDate
            syncStatus = .synced
            
            print("[CloudKit] Fetch succeeded (public DB)")
            return cloudGameData
            
        } catch let ckError as CKError where ckError.code == .unknownItem {
            // No cloud save exists yet — that's fine
            print("[CloudKit] No cloud save found")
            syncStatus = .idle
            return nil
        } catch let ckError as CKError {
            let friendly = friendlyErrorMessage(for: ckError)
            syncStatus = .error(friendly)
            print("[CloudKit] Fetch failed: \(ckError.localizedDescription)")
            return nil
        } catch {
            syncStatus = .error(error.localizedDescription)
            print("[CloudKit] Fetch failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Restore
    
    /// Fetches cloud data and replaces local data if cloud data exists.
    /// Returns true if data was restored.
    @discardableResult
    func restoreFromCloud() async -> Bool {
        guard let cloudData = await fetchFromCloud() else {
            return false
        }
        
        // Replace local data
        let gameDataManager = GameDataManager.shared
        gameDataManager.replaceGameData(cloudData)
        
        print("[CloudKit] Restored game data from cloud")
        return true
    }
    
    // MARK: - Auto-Sync on Launch
    
    /// Called on app launch. If signed in, checks for cloud data.
    /// If local data is empty (new device), restores from cloud.
    /// Otherwise, pushes local data to keep cloud up to date.
    func syncOnLaunch() async {
        // Wait for iCloud status to be determined (fixes race condition)
        await refreshiCloudStatus()
        
        guard iCloudAvailable else {
            print("[CloudKit] iCloud not available — skipping sync on launch")
            return
        }
        
        // Pre-fetch the user record name so subsequent operations are fast
        guard await ensureUserRecordName() != nil else { return }
        
        let localData = GameDataManager.shared.gameData
        
        // Determine if local data has REAL player progress (not just starter eggs).
        // A fresh install gets 9 FarmEggs by default, so purchasedEggs alone doesn't count.
        let hasRealProgress = !localData.unlockedAnimals.isEmpty
            || !localData.animalInstances.isEmpty
            || localData.totalCoins > 100  // Starter coins from day-1 streak are <= 100
            || localData.currentStreak > 1
            || localData.totalStudyTime > 0
        
        if !hasRealProgress {
            // New device / fresh install — try to restore from cloud
            let restored = await restoreFromCloud()
            if restored {
                print("[CloudKit] Auto-restored from cloud (new device)")
            }
        } else {
            // Existing device with real progress — push local state to cloud
            await pushToCloud(gameData: localData)
        }
        
        // Load persisted last sync date
        if lastSyncDate == nil {
            lastSyncDate = UserDefaults.standard.object(forKey: "CloudKitLastSyncDate") as? Date
        }
    }
    
    // MARK: - Sync After Sign-In
    
    /// Called after the user signs in with Apple. Always fetches cloud data
    /// and picks whichever save has more real progress (animals, study time, etc.).
    /// This ensures a returning user on a new device gets their data back,
    /// even if they used the app briefly before signing in.
    func syncAfterSignIn() async {
        await refreshiCloudStatus()
        
        guard iCloudAvailable else {
            print("[CloudKit] iCloud not available — skipping post-sign-in sync")
            return
        }
        
        guard await ensureUserRecordName() != nil else { return }
        
        let localData = GameDataManager.shared.gameData
        
        // Always fetch cloud data to compare
        guard let cloudData = await fetchFromCloud() else {
            // No cloud save exists — push local data up
            print("[CloudKit] No cloud save found after sign-in — pushing local data")
            await pushToCloud(gameData: localData)
            return
        }
        
        // Compare which save has more real progress
        let localScore = progressScore(for: localData)
        let cloudScore = progressScore(for: cloudData)
        
        print("[CloudKit] Sign-in sync — local progress score: \(localScore), cloud progress score: \(cloudScore)")
        
        if cloudScore > localScore {
            // Cloud has more progress — restore it (returning user on a new device)
            GameDataManager.shared.replaceGameData(cloudData)
            print("[CloudKit] Restored cloud save after sign-in (cloud had more progress)")
        } else if localScore > cloudScore {
            // Local has more progress — push it to cloud
            await pushToCloud(gameData: localData)
            print("[CloudKit] Pushed local save after sign-in (local had more progress)")
        } else {
            // Equal progress — push local to keep cloud fresh
            await pushToCloud(gameData: localData)
            print("[CloudKit] Pushed local save after sign-in (equal progress)")
        }
        
        // Load persisted last sync date
        if lastSyncDate == nil {
            lastSyncDate = UserDefaults.standard.object(forKey: "CloudKitLastSyncDate") as? Date
        }
    }
    
    /// Calculates a numeric score representing how much real progress a GameData has.
    /// Used to decide which save (local vs cloud) should win during sign-in sync.
    private func progressScore(for data: GameData) -> Int {
        var score = 0
        score += data.animalInstances.count * 100   // Animals are the most valuable
        score += data.unlockedAnimals.count * 50
        score += min(data.totalCoins, 10000)         // Cap so coins don't dominate
        score += data.currentStreak * 20
        score += Int(data.totalStudyTime / 60) * 10  // Minutes of study time
        score += data.unlockedGraves.count * 30
        return score
    }
    
    // MARK: - Delete Cloud Data
    
    func deleteCloudData() async {
        guard let userName = await ensureUserRecordName() else { return }
        let recID = recordID(for: userName)
        
        do {
            try await publicDB.deleteRecord(withID: recID)
            lastSyncDate = nil
            syncStatus = .idle
            UserDefaults.standard.removeObject(forKey: "CloudKitLastSyncDate")
            print("[CloudKit] Cloud data deleted")
        } catch {
            print("[CloudKit] Delete failed: \(error.localizedDescription)")
        }
    }
}
