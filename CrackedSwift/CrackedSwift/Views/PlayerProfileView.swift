//
//  PlayerProfileView.swift
//  Fauna
//
//  Shows a player's profile from the leaderboard with stats and friend option
//

import SwiftUI

struct PlayerProfileView: View {
    let entry: LeaderboardEntry
    @Environment(\.dismiss) private var dismiss
    @StateObject private var leaderboard = LeaderboardManager.shared
    
    @State private var isSending = false
    @State private var requestSent = false
    @State private var errorText: String?
    
    private var isFriend: Bool {
        leaderboard.friends.contains { $0.friendID == entry.id }
    }
    
    private var hasPendingRequest: Bool {
        leaderboard.outgoingRequests.contains { $0.toUserID == entry.id }
    }
    
    private var isMe: Bool {
        entry.id == leaderboard.myUserID
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGreen
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar & name
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.buttonGreen.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 70))
                                    .foregroundColor(AppColors.buttonGreen)
                            }
                            
                            Text(entry.displayName)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(entry.rankBadge)
                                .font(.title2)
                        }
                        .padding(.top, 20)
                        
                        // Stats grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            statCard(
                                icon: "pawprint.fill",
                                label: "Animals Hatched",
                                value: "\(entry.animalsHatched)",
                                color: .green
                            )
                            
                            statCard(
                                icon: "clock.fill",
                                label: "Study Time",
                                value: entry.formattedStudyTime,
                                color: .blue
                            )
                            
                            statCard(
                                icon: "flame.fill",
                                label: "Current Streak",
                                value: "\(entry.currentStreak) days",
                                color: .orange
                            )
                            
                            statCard(
                                icon: "circle.fill",
                                label: "Total Coins",
                                value: "\(entry.totalCoins)",
                                color: AppColors.coinGold
                            )
                        }
                        .padding(.horizontal)
                        
                        // Last active
                        Text("Last active \(entry.lastUpdated, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                        
                        // Friend action button
                        if !isMe {
                            friendActionButton
                                .padding(.horizontal, 40)
                                .padding(.top, 8)
                        }
                        
                        if let error = errorText {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Friend Action Button
    
    @ViewBuilder
    private var friendActionButton: some View {
        if isFriend {
            Label("Friends", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundColor(.green)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.15))
                .cornerRadius(12)
        } else if hasPendingRequest || requestSent {
            Label("Request Sent", systemImage: "clock.fill")
                .font(.headline)
                .foregroundColor(.yellow)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.yellow.opacity(0.15))
                .cornerRadius(12)
        } else {
            Button {
                Task {
                    isSending = true
                    errorText = nil
                    let success = await leaderboard.sendFriendRequestToUser(
                        targetID: entry.id,
                        targetName: entry.displayName
                    )
                    if success {
                        requestSent = true
                    } else {
                        errorText = leaderboard.errorMessage
                    }
                    isSending = false
                }
            } label: {
                HStack {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "person.badge.plus")
                    }
                    Text("Add Friend")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(AppColors.buttonGreen)
                .cornerRadius(12)
            }
            .disabled(isSending)
        }
    }
    
    // MARK: - Stat Card
    
    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(12)
    }
}

#Preview {
    PlayerProfileView(entry: LeaderboardEntry(
        id: "test",
        displayName: "TestPlayer",
        animalsHatched: 42,
        totalStudyTime: 7200,
        currentStreak: 5,
        totalCoins: 1500,
        lastUpdated: Date()
    ))
}
