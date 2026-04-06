//
//  AccountView.swift
//  CrackedSwift
//
//  Account / profile sheet. Shows Sign in with Apple when signed out,
//  or profile info + sign out when signed in.
//

import SwiftUI
import AuthenticationServices

struct AccountView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var cloudKit = CloudKitManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingRestoreConfirm = false
    @State private var showingBackupConfirm = false
    @State private var showingNameEdit = false
    @State private var editedName = ""
    @State private var showingDeleteConfirm = false
    @State private var showingDeleteFinalConfirm = false
    @State private var isDeletingAccount = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGreen
                    .ignoresSafeArea()
                
                if authManager.isSignedIn {
                    signedInContent
                } else {
                    signedOutContent
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Signed In
    
    private var signedInContent: some View {
        VStack(spacing: 0) {
            List {
                // Profile section
                Section {
                    HStack(spacing: 16) {
                        // Avatar circle with initials
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.buttonGreen, AppColors.backgroundGreen],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                            
                            Text(initials)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // Display name (read-only after initial setup)
                            Text(authManager.userProfile?.displayName ?? "No name set")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(authManager.userProfile?.displayName != nil ? .white : .white.opacity(0.5))
                            
                            if let email = authManager.userProfile?.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Profile")
                        .foregroundColor(.white.opacity(0.8))
                }
                .listRowBackground(Color.clear)
                
                // Stats section
                Section {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .frame(width: 30)
                        Text("Current Streak")
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(GameDataManager.shared.getCurrentStreak()) days")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Image(systemName: "pawprint.fill")
                            .foregroundColor(AppColors.buttonGreen)
                            .frame(width: 30)
                        Text("Animals Hatched")
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(GameDataManager.shared.getAnimalInstancesCount())")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundColor(AppColors.coinGold)
                            .frame(width: 30)
                        Text("Total Coins")
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(GameDataManager.shared.getTotalCoins())")
                            .foregroundColor(.gray)
                    }
                } header: {
                    Text("Stats")
                        .foregroundColor(.white.opacity(0.8))
                }
                .listRowBackground(Color.clear)
                
                // iCloud sync section
                Section {
                    // Sync status row
                    HStack {
                        Image(systemName: cloudKit.iCloudAvailable ? "icloud.fill" : "icloud.slash")
                            .foregroundColor(cloudKit.iCloudAvailable ? .blue : .gray)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("iCloud Sync")
                                .foregroundColor(.white)
                            
                            Text(syncStatusText)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if cloudKit.syncStatus == .syncing {
                            ProgressView()
                                .tint(.white)
                        } else if cloudKit.syncStatus == .synced {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    
                    // Backup now button
                    Button(action: {
                        showingBackupConfirm = true
                    }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            Text("Back Up Now")
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(cloudKit.syncStatus == .syncing || !cloudKit.iCloudAvailable)
                    
                    // Restore from cloud button
                    Button(action: {
                        showingRestoreConfirm = true
                    }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            Text("Restore from iCloud")
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(cloudKit.syncStatus == .syncing || !cloudKit.iCloudAvailable)
                } header: {
                    Text("Cloud Backup")
                        .foregroundColor(.white.opacity(0.8))
                }
                .listRowBackground(Color.clear)
                
                // Sign out section
                Section {
                    Button(action: {
                        authManager.signOut()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                                .frame(width: 30)
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                
                // Delete account section
                Section {
                    Button(action: {
                        showingDeleteConfirm = true
                    }) {
                        HStack {
                            if isDeletingAccount {
                                ProgressView()
                                    .tint(.red)
                                    .frame(width: 30)
                            } else {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.red)
                                    .frame(width: 30)
                            }
                            Text("Delete Account")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isDeletingAccount)
                } footer: {
                    Text("Permanently deletes your account and all associated data including cloud saves, leaderboard stats, and friend connections. This action cannot be undone.")
                        .foregroundColor(.white.opacity(0.5))
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            .alert("Back Up to iCloud?", isPresented: $showingBackupConfirm) {
                Button("Back Up", role: .none) {
                    Task {
                        await cloudKit.saveNow(gameData: GameDataManager.shared.gameData)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will upload your current game data to iCloud, replacing any existing cloud save.")
            }
            .alert("Restore from iCloud?", isPresented: $showingRestoreConfirm) {
                Button("Restore", role: .destructive) {
                    Task {
                        await cloudKit.restoreFromCloud()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will replace your current local data with the cloud save. Any local progress not backed up will be lost.")
            }
            .alert("Delete Account?", isPresented: $showingDeleteConfirm) {
                Button("Delete Account", role: .destructive) {
                    showingDeleteFinalConfirm = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account, all game progress, cloud saves, leaderboard data, and friend connections. This action cannot be undone.")
            }
            .alert("Are you sure?", isPresented: $showingDeleteFinalConfirm) {
                Button("Delete Everything", role: .destructive) {
                    isDeletingAccount = true
                    Task {
                        await authManager.deleteAccount()
                        isDeletingAccount = false
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This is your last chance. All data will be permanently erased and cannot be recovered.")
            }
        }
    }
    
    // MARK: - Signed Out
    
    private var signedOutContent: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: "person.crop.circle")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Sign In")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Sign in to save your identity for social features and leaderboards.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Sign in with Apple button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                authManager.handleSignInResult(result)
                if authManager.isSignedIn {
                    // Restore account data (animals, coins, etc.) from cloud
                    Task {
                        await CloudKitManager.shared.syncAfterSignIn()
                    }
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .cornerRadius(12)
            .padding(.horizontal, 40)
            
            if let error = authManager.authError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Helpers
    
    private var initials: String {
        guard let name = authManager.userProfile?.displayName else { return "?" }
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }
        return letters.joined()
    }
    
    private var syncStatusText: String {
        if !cloudKit.iCloudAvailable {
            return "iCloud not available — sign in to iCloud in Settings"
        }
        switch cloudKit.syncStatus {
        case .idle:
            if let date = cloudKit.lastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                return "Last synced \(formatter.localizedString(for: date, relativeTo: Date()))"
            }
            return "Not yet synced"
        case .syncing:
            return "Syncing..."
        case .synced:
            if let date = cloudKit.lastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
            }
            return "Synced"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

#Preview {
    AccountView()
}
