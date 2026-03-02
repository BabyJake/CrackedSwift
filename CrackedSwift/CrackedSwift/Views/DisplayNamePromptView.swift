//
//  DisplayNamePromptView.swift
//  CrackedSwift
//
//  One-time prompt shown right after sign-in so the user can pick
//  the display name that will appear on leaderboards and to friends.
//  Once confirmed, the name cannot be changed.
//

import SwiftUI

struct DisplayNamePromptView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var name: String = ""
    @FocusState private var isFocused: Bool
    
    /// Pre-fill with the name Apple gave us (if any)
    private var suggestedName: String {
        authManager.userProfile?.displayName ?? ""
    }
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isValid: Bool {
        let t = trimmedName
        return t.count >= 2 && t.count <= 20
    }
    
    var body: some View {
        ZStack {
            AppColors.backgroundGreen
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                Spacer()
                
                // Icon
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 56))
                    .foregroundColor(.white.opacity(0.8))
                
                // Title
                Text("Choose Your Name")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Description
                Text("Pick a display name for leaderboards and friends.\nThis can only be set once, so choose wisely!")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Name field
                VStack(spacing: 8) {
                    TextField("Your display name", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                        .focused($isFocused)
                        .padding()
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(14)
                        .padding(.horizontal, 40)
                        .onChange(of: name) { _, newValue in
                            // Cap at 20 characters
                            if newValue.count > 20 {
                                name = String(newValue.prefix(20))
                            }
                        }
                    
                    Text("\(trimmedName.count)/20 characters")
                        .font(.caption)
                        .foregroundColor(isValid ? .white.opacity(0.5) : .orange)
                }
                
                Spacer()
                
                // Confirm button
                Button {
                    authManager.confirmDisplayName(trimmedName)
                    authManager.hasSeenAccountPrompt = true
                    // Also push to leaderboard
                    Task {
                        await LeaderboardManager.shared.pushStats()
                    }
                } label: {
                    Text("Confirm Name")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValid ? AppColors.buttonGreen : Color.gray.opacity(0.4))
                        .cornerRadius(14)
                        .padding(.horizontal, 40)
                }
                .disabled(!isValid)
                
                Text("This cannot be changed later")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                
                Spacer()
            }
        }
        .onAppear {
            // Pre-fill with Apple-provided name if available
            name = suggestedName
            isFocused = true
        }
    }
}

#Preview {
    DisplayNamePromptView()
        .environmentObject(AuthManager.shared)
}
