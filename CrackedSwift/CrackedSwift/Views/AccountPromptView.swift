//
//  AccountPromptView.swift
//  CrackedSwift
//
//  One-time prompt shown on first launch encouraging the user to sign in.
//  They can sign in with Apple or skip — but skipping warns them that
//  their data won't be backed up to the cloud.
//

import SwiftUI
import AuthenticationServices

struct AccountPromptView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showingSkipWarning = false
    
    var body: some View {
        ZStack {
            AppColors.backgroundGreen
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                Spacer()
                
                // Icon
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.8))
                
                // Title
                Text("Protect Your Progress")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Description
                VStack(spacing: 12) {
                    Text("Sign in to back up your animals, coins, and streak to the cloud.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("If you switch phones or delete the app, you'll be able to restore everything.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Sign in with Apple button
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authManager.handleSignInResult(result)
                    if authManager.isSignedIn {
                        // Don't set hasSeenAccountPrompt yet — the display name prompt will do that
                        // Restore account data from cloud
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
                
                // Skip button
                Button(action: {
                    showingSkipWarning = true
                }) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .underline()
                }
                .padding(.top, 4)
                
                Spacer()
            }
        }
        .alert("Are you sure?", isPresented: $showingSkipWarning) {
            Button("Skip Anyway", role: .destructive) {
                authManager.hasSeenAccountPrompt = true
            }
            Button("Sign In Instead", role: .cancel) {}
        } message: {
            Text("Without an account, your animals, coins, and progress will NOT be saved if you delete the app or get a new phone. You can always sign in later from the profile button.")
        }
    }
}

#Preview {
    AccountPromptView()
}
