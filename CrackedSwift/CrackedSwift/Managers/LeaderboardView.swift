//
//  LeaderboardView.swift
//  CrackedSwift
//
//  Leaderboard with global/friend rankings and friend management
//

import SwiftUI

struct LeaderboardView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var leaderboard = LeaderboardManager.shared
    
    @State private var selectedScope: LeaderboardScope = .global
    @State private var selectedCategory: LeaderboardCategory = .animalsHatched
    @State private var showingAddFriend = false
    @State private var showingFriendsList = false
    @State private var showingMyProfile = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGreen
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Scope picker (Global / Friends)
                    Picker("Scope", selection: $selectedScope) {
                        ForEach(LeaderboardScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Category picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LeaderboardCategory.allCases) { category in
                                CategoryChip(
                                    category: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    withAnimation { selectedCategory = category }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    
                    // Friend requests banner
                    if !leaderboard.incomingRequests.isEmpty {
                        Button {
                            showingFriendsList = true
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("\(leaderboard.incomingRequests.count) friend request\(leaderboard.incomingRequests.count == 1 ? "" : "s")")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.orange.opacity(0.3))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                    
                    // Leaderboard list
                    if leaderboard.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("Loading...")
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 8)
                        Spacer()
                    } else {
                        let entries = selectedScope == .global
                            ? leaderboard.sortedEntries(leaderboard.globalEntries, by: selectedCategory)
                            : leaderboard.sortedEntries(leaderboard.friendEntries, by: selectedCategory)
                        
                        if entries.isEmpty {
                            Spacer()
                            VStack(spacing: 16) {
                                Image(systemName: selectedScope == .friends ? "person.2.slash" : "chart.bar")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                if selectedScope == .friends {
                                    Text("No friends yet!")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("Add friends by searching their username\nto see how you compare.")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                    
                                    Button {
                                        showingAddFriend = true
                                    } label: {
                                        Label("Add a Friend", systemImage: "person.badge.plus")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(AppColors.buttonGreen)
                                            .cornerRadius(12)
                                    }
                                } else {
                                    Text("No leaderboard data yet")
                                        .font(.title3)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                                        LeaderboardRow(
                                            rank: index + 1,
                                            entry: entry,
                                            category: selectedCategory,
                                            isMe: entry.id == leaderboard.myUserID
                                        )
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingMyProfile = true
                        } label: {
                            Label("My Username", systemImage: "person.circle")
                        }
                        
                        Button {
                            showingAddFriend = true
                        } label: {
                            Label("Add Friend", systemImage: "person.badge.plus")
                        }
                        
                        Button {
                            showingFriendsList = true
                        } label: {
                            Label("Friends (\(leaderboard.friends.count))", systemImage: "person.2")
                        }
                        
                        Divider()
                        
                        Button {
                            Task { await leaderboard.refreshAll() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView()
            }
            .sheet(isPresented: $showingFriendsList) {
                FriendsListView()
            }
            .sheet(isPresented: $showingMyProfile) {
                MyUsernameView()
            }
            .task {
                await leaderboard.setup()
            }
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: LeaderboardCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? AppColors.buttonGreen : Color.white.opacity(0.1))
            .cornerRadius(20)
        }
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    let category: LeaderboardCategory
    let isMe: Bool
    
    @State private var showingProfile = false
    
    private var rankDisplay: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text(rankDisplay)
                .font(rank <= 3 ? .title2 : .headline)
                .frame(width: 40)
            
            // Player info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.displayName)
                        .font(.headline)
                        .foregroundColor(isMe ? .yellow : .white)
                        .lineLimit(1)
                    
                    if isMe {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.yellow.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            // Value
            Text(LeaderboardManager.shared.valueString(for: entry, category: category))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(isMe ? .yellow : .white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isMe ? Color.yellow.opacity(0.15) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isMe ? Color.yellow.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if !isMe { showingProfile = true }
        }
        .sheet(isPresented: $showingProfile) {
            PlayerProfileView(entry: entry)
        }
    }
}

// MARK: - Add Friend View

struct AddFriendView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var leaderboard = LeaderboardManager.shared
    @State private var searchText: String = ""
    @State private var isSending = false
    @State private var successMessage: String?
    @State private var sentToIDs: Set<String> = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGreen
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.5))
                        
                        TextField("Search by username...", text: $searchText)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: searchText) { _, newValue in
                                Task {
                                    await leaderboard.searchUsers(query: newValue)
                                }
                            }
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                leaderboard.searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    
                    if let error = leaderboard.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    if let success = successMessage {
                        Text(success)
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal)
                    }
                    
                    // Results
                    if searchText.count < 2 {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.badge.magnifyingglass")
                                .font(.system(size: 44))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Search for players by username")
                                .foregroundColor(.white.opacity(0.5))
                            Text("Type at least 2 characters")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.3))
                        }
                        Spacer()
                    } else if leaderboard.isSearching {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Text("Searching...")
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                    } else if leaderboard.searchResults.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 44))
                                .foregroundColor(.white.opacity(0.3))
                            Text("No players found")
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(leaderboard.searchResults) { entry in
                                    HStack(spacing: 12) {
                                        Image(systemName: "person.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(AppColors.buttonGreen)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.displayName)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text("\(entry.animalsHatched) animals hatched")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        
                                        Spacer()
                                        
                                        if leaderboard.friends.contains(where: { $0.friendID == entry.id }) {
                                            Text("Friends")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.green.opacity(0.2))
                                                .cornerRadius(8)
                                        } else if sentToIDs.contains(entry.id) {
                                            Text("Sent")
                                                .font(.caption)
                                                .foregroundColor(.yellow)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.yellow.opacity(0.2))
                                                .cornerRadius(8)
                                        } else {
                                            Button {
                                                Task {
                                                    isSending = true
                                                    let result = await leaderboard.sendFriendRequestToUser(
                                                        targetID: entry.id,
                                                        targetName: entry.displayName
                                                    )
                                                    if result {
                                                        sentToIDs.insert(entry.id)
                                                        successMessage = "Request sent to \(entry.displayName)!"
                                                    }
                                                    isSending = false
                                                }
                                            } label: {
                                                Image(systemName: "person.badge.plus")
                                                    .font(.title3)
                                                    .foregroundColor(AppColors.buttonGreen)
                                            }
                                            .disabled(isSending)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .onDisappear {
                leaderboard.searchResults = []
                leaderboard.errorMessage = nil
            }
        }
    }
}

// MARK: - My Username View

struct MyUsernameView: View {
    @Environment(\.dismiss) var dismiss
    @State private var copied = false
    
    private var username: String {
        AuthManager.shared.userProfile?.displayName ?? "Not set"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGreen
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Your Username")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Friends can find and add you by searching this name!")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Text(username)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.yellow)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 30)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(16)
                    
                    Button {
                        UIPasteboard.general.string = username
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied!" : "Copy Username")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppColors.buttonGreen)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                    }
                    
                    ShareLink(item: "Add me on Cracked! My username: \(username)") {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Username")
                        }
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Username")
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
}

// MARK: - Friends List View

struct FriendsListView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var leaderboard = LeaderboardManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGreen
                    .ignoresSafeArea()
                
                List {
                    // Incoming requests
                    if !leaderboard.incomingRequests.isEmpty {
                        Section {
                            ForEach(leaderboard.incomingRequests) { request in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(request.fromDisplayName)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("Wants to be friends")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        Task { await leaderboard.acceptFriendRequest(request) }
                                    } label: {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title2)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button {
                                        Task { await leaderboard.declineFriendRequest(request) }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.title2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } header: {
                            Text("Requests (\(leaderboard.incomingRequests.count))")
                                .foregroundColor(.orange)
                        }
                        .listRowBackground(Color.orange.opacity(0.15))
                    }
                    
                    // Pending outgoing
                    if !leaderboard.outgoingRequests.isEmpty {
                        Section {
                            ForEach(leaderboard.outgoingRequests) { request in
                                HStack {
                                    Text(request.toUserID.prefix(8) + "...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("Pending")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.yellow.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        } header: {
                            Text("Sent Requests")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                    
                    // Friends
                    Section {
                        if leaderboard.friends.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "person.2.slash")
                                        .font(.title)
                                        .foregroundColor(.white.opacity(0.3))
                                    Text("No friends yet")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.vertical, 20)
                                Spacer()
                            }
                        } else {
                            ForEach(leaderboard.friends) { friend in
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(AppColors.buttonGreen)
                                    
                                    VStack(alignment: .leading) {
                                        Text(friend.friendDisplayName)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("Friends since \(friend.since, style: .date)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    
                                    Spacer()
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await leaderboard.removeFriend(friend) }
                                    } label: {
                                        Label("Remove", systemImage: "person.badge.minus")
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Friends (\(leaderboard.friends.count))")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .listRowBackground(Color.white.opacity(0.08))
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .refreshable {
                await leaderboard.refreshAll()
            }
        }
    }
}

#Preview {
    LeaderboardView()
}