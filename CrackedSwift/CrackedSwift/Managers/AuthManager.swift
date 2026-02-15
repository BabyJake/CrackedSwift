//
//  AuthManager.swift
//  CrackedSwift
//
//  Handles Sign in with Apple authentication, Keychain storage of the
//  Apple user identifier, and credential state monitoring.
//

import Foundation
import AuthenticationServices
import Security

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    // MARK: - Published State
    
    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var userProfile: UserProfile?
    @Published var authError: String?
    
    /// Whether the user has seen the one-time account setup prompt (signed in or skipped).
    @Published var hasSeenAccountPrompt: Bool {
        didSet { userDefaults.set(hasSeenAccountPrompt, forKey: accountPromptKey) }
    }
    
    // MARK: - Storage Keys
    
    private let keychainService = "com.cracked.auth"
    private let keychainAccountKey = "appleUserID"
    private let profileKey = "FaunaUserProfile"
    private let accountPromptKey = "FaunaHasSeenAccountPrompt"
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Init
    
    private init() {
        self.hasSeenAccountPrompt = userDefaults.bool(forKey: accountPromptKey)
        loadProfile()
        listenForRevocation()
    }
    
    // MARK: - Credential State Check
    
    /// Call on app launch to verify the Apple ID credential is still valid.
    func checkCredentialState() {
        guard let userID = readUserIDFromKeychain() else {
            signOutLocally()
            return
        }
        
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userID) { [weak self] state, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch state {
                case .authorized:
                    // Credential still valid
                    self.isSignedIn = true
                    
                    // If profile is missing (app was reinstalled — Keychain survives but
                    // UserDefaults doesn't), create a minimal profile from the Keychain user ID
                    // so the user is properly signed in. They can edit their name later.
                    if self.userProfile == nil {
                        let restoredProfile = UserProfile(userID: userID)
                        self.userProfile = restoredProfile
                        self.saveProfile(restoredProfile)
                        self.hasSeenAccountPrompt = true // Don't show the prompt again
                    }
                case .revoked, .notFound:
                    // User revoked access or credential not found — sign out
                    self.signOutLocally()
                case .transferred:
                    // Account transferred to a different team — treat as signed out
                    self.signOutLocally()
                @unknown default:
                    break
                }
            }
        }
    }
    
    // MARK: - Sign In with Apple
    
    /// Handles the result from `SignInWithAppleButton`.
    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authError = "Unexpected credential type."
                return
            }
            
            let userID = credential.user
            
            // Build display name from components (only available on first sign-in)
            var displayName: String?
            if let fullName = credential.fullName {
                let components = [fullName.givenName, fullName.familyName].compactMap { $0 }
                if !components.isEmpty {
                    displayName = components.joined(separator: " ")
                }
            }
            
            let email = credential.email
            
            // Save user ID to Keychain
            saveUserIDToKeychain(userID)
            
            // Build profile — preserve existing name/email if Apple didn't provide them
            // (Apple only sends name/email on the very first authorization)
            let existingProfile = userProfile
            let finalName = displayName ?? existingProfile?.displayName
            let finalEmail = email ?? existingProfile?.email
            
            let profile = UserProfile(
                userID: userID,
                displayName: finalName,
                email: finalEmail
            )
            
            self.userProfile = profile
            self.isSignedIn = true
            self.authError = nil
            saveProfile(profile)
            
            print("[Auth] Signed in as: \(finalName ?? userID)")
            
        case .failure(let error):
            // ASAuthorizationError.canceled means user dismissed the sheet — not a real error
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                return
            }
            authError = error.localizedDescription
            print("[Auth] Sign in failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Profile Updates
    
    /// Allows the user to set or change their display name (since Apple only provides it once).
    func updateDisplayName(_ name: String) {
        guard var profile = userProfile else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.displayName = trimmed.isEmpty ? nil : trimmed
        self.userProfile = profile
        saveProfile(profile)
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        signOutLocally()
    }
    
    private func signOutLocally() {
        isSignedIn = false
        userProfile = nil
        authError = nil
        deleteUserIDFromKeychain()
        userDefaults.removeObject(forKey: profileKey)
    }
    
    // MARK: - Revocation Listener
    
    private func listenForRevocation() {
        NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.signOutLocally()
            }
        }
    }
    
    // MARK: - Profile Persistence (UserDefaults)
    
    private func loadProfile() {
        guard let data = userDefaults.data(forKey: profileKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            isSignedIn = false
            return
        }
        
        // Only mark as signed in if we also have the Keychain credential
        if readUserIDFromKeychain() != nil {
            self.userProfile = profile
            self.isSignedIn = true
        } else {
            // Profile exists but Keychain was cleared — clean up
            userDefaults.removeObject(forKey: profileKey)
            isSignedIn = false
        }
    }
    
    private func saveProfile(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            userDefaults.set(data, forKey: profileKey)
        }
    }
    
    // MARK: - Keychain Helpers
    
    private func saveUserIDToKeychain(_ userID: String) {
        // Delete any existing item first
        deleteUserIDFromKeychain()
        
        guard let data = userID.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccountKey,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[Auth] Keychain save failed: \(status)")
        }
    }
    
    private func readUserIDFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccountKey,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    private func deleteUserIDFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccountKey
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
