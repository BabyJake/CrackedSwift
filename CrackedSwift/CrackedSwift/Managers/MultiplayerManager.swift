//
//  MultiplayerManager.swift
//  CrackedSwift
//
//  Handles multiplayer connections and synchronization for co-op egg hatching using GameKit
//

import Foundation
import GameKit
import Combine
import UIKit
import SwiftUI

@MainActor
class MultiplayerManager: NSObject, ObservableObject {
    static let shared = MultiplayerManager()
    
    // Published state
    @Published var isConnected: Bool = false
    @Published var connectedPeerName: String?
    @Published var isAuthenticated: Bool = false
    @Published var authenticationError: String?
    @Published var isSearchingForMatch: Bool = false
    
    // Multiplayer session state
    @Published var friendTimerState: FriendTimerState?
    @Published var friendEggType: String?
    
    // GameKit components
    private var match: GKMatch?
    private var matchmakerViewController: GKMatchmakerViewController?
    private var isPresentingMatchmaker: Bool = false
    private var localPlayer: GKLocalPlayer { GKLocalPlayer.local }
    
    // Callbacks
    var onFriendCrackedEgg: ((String) -> Void)? // Called when friend cracks their egg
    var onFriendTimerUpdated: ((TimeInterval) -> Void)? // Called when friend's timer updates
    var onFriendTimerCompleted: (() -> Void)? // Called when friend completes timer
    
    struct FriendTimerState: Codable {
        let timeRemaining: TimeInterval
        let isRunning: Bool
        let eggType: String?
    }
    
    // Message types for communication
    private enum MessageType: String, Codable {
        case timerState
        case eggCracked
        case timerCompleted
    }
    
    private struct Message: Codable {
        let type: MessageType
        let data: Data?
    }
    
    override init() {
        super.init()
        authenticatePlayer()
    }
    
    // MARK: - Authentication
    
    func authenticatePlayer() {
        // Only set handler if not already authenticated
        guard !localPlayer.isAuthenticated else {
            isAuthenticated = true
            authenticationError = nil
            print("✅ [GameKit] Player already authenticated: \(localPlayer.displayName)")
            return
        }
        
        localPlayer.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let viewController = viewController {
                    // Present authentication view controller
                    self.presentAuthenticationViewController(viewController)
                    return
                }
                
                if let error = error {
                    let errorDescription = error.localizedDescription
                    print("❌ [GameKit] Authentication failed: \(errorDescription)")
                    
                    // Check if it's the "app not recognized" error
                    if errorDescription.contains("not recognised") || errorDescription.contains("not recognized") {
                        // Player might still be authenticated even if app isn't recognized
                        if self.localPlayer.isAuthenticated {
                            self.isAuthenticated = true
                            self.authenticationError = "App setup incomplete.\n\nTo fix:\n1. Go to App Store Connect\n2. Create app (if needed)\n3. Enable Game Center in Features tab\n4. Wait 5-10 minutes\n5. Restart app\n\nSee FIX_GAMECENTER_NOT_RECOGNIZED.md for details."
                            print("⚠️ [GameKit] Player authenticated but app not recognized")
                        } else {
                            self.isAuthenticated = false
                            self.authenticationError = "App not recognized by Game Center.\n\nQuick fix:\n1. App Store Connect → Create app\n2. Enable Game Center\n3. Wait 5-10 minutes\n4. Restart app\n\nSee FIX_GAMECENTER_NOT_RECOGNIZED.md"
                        }
                    } else {
                        self.isAuthenticated = false
                        self.authenticationError = errorDescription
                    }
                    return
                }
                
                // Check authentication status
                if self.localPlayer.isAuthenticated {
                    self.isAuthenticated = true
                    self.authenticationError = nil
                    print("✅ [GameKit] Player authenticated: \(self.localPlayer.displayName)")
                } else {
                    self.isAuthenticated = false
                    self.authenticationError = "Please sign in to Game Center in Settings"
                    print("⚠️ [GameKit] Player not authenticated - sign in required")
                }
            }
        }
    }
    
    private func presentAuthenticationViewController(_ viewController: UIViewController) {
        // Find the root view controller and present
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(viewController, animated: true)
        }
    }
    
    // MARK: - Matchmaking
    
    func startMatchmaking() {
        guard isAuthenticated else {
            print("⚠️ [GameKit] Cannot start matchmaking - not authenticated")
            authenticationError = "Please sign in to Game Center first"
            return
        }
        
        guard match == nil else {
            print("⚠️ [GameKit] Match already in progress")
            return
        }
        
        guard !isPresentingMatchmaker else {
            print("⚠️ [GameKit] Matchmaker already presenting")
            return
        }
        
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.inviteMessage = "Let's hatch eggs together!"
        
        // Create matchmaker view controller
        guard let matchmakerVC = GKMatchmakerViewController(matchRequest: request) else {
            print("❌ [GameKit] Failed to create matchmaker view controller")
            authenticationError = "Failed to create matchmaker. Ensure Game Center is enabled in App Store Connect."
            return
        }
        
        matchmakerVC.matchmakerDelegate = self
        matchmakerViewController = matchmakerVC
        isPresentingMatchmaker = true
        
        // Find the topmost view controller to present from
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let topViewController = self.getTopViewController() {
                topViewController.present(matchmakerVC, animated: true) {
                    print("✅ [GameKit] Matchmaker presented")
                }
            } else {
                print("❌ [GameKit] Could not find view controller to present from")
                self.isPresentingMatchmaker = false
                self.authenticationError = "Could not show matchmaker. Please try again."
            }
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        
        var topViewController = window.rootViewController
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        
        return topViewController
    }
    
    func startAutoMatchmaking() {
        guard isAuthenticated else {
            print("⚠️ [GameKit] Cannot start matchmaking - not authenticated")
            authenticationError = "Please sign in to Game Center first"
            return
        }
        
        guard match == nil else {
            print("⚠️ [GameKit] Match already in progress")
            return
        }
        
        guard !isSearchingForMatch else {
            print("⚠️ [GameKit] Already searching for match")
            return
        }
        
        isSearchingForMatch = true
        authenticationError = nil
        print("🔍 [GameKit] Starting Quick Match search...")
        
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        
        let matchmaker = GKMatchmaker.shared()
        matchmaker.findMatch(for: request) { [weak self] match, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isSearchingForMatch = false
                
                if let error = error {
                    let errorDescription = error.localizedDescription
                    print("❌ [GameKit] Auto-matchmaking failed: \(errorDescription)")
                    
                    // Check for specific error about app not being recognized
                    if errorDescription.contains("not recognised") || errorDescription.contains("not recognized") {
                        self.authenticationError = "App not recognized by Game Center. Please:\n1. Enable Game Center in App Store Connect\n2. Ensure Bundle ID matches\n3. Wait a few minutes for propagation"
                    } else {
                        self.authenticationError = "Matchmaking failed: \(errorDescription)"
                    }
                    return
                }
                
                if let match = match {
                    self.match = match
                    match.delegate = self
                    self.handleMatchStarted(match)
                    print("✅ [GameKit] Quick Match found player!")
                }
            }
        }
    }
    
    func disconnect() {
        match?.disconnect()
        match = nil
        matchmakerViewController?.dismiss(animated: true)
        matchmakerViewController = nil
        
        isConnected = false
        isSearchingForMatch = false
        connectedPeerName = nil
        friendTimerState = nil
        friendEggType = nil
        
        print("🔌 [GameKit] Disconnected")
    }
    
    // MARK: - Match Handling
    
    private func handleMatchStarted(_ match: GKMatch) {
        // Get opponent's name
        if let opponent = match.players.first(where: { $0.playerID != localPlayer.playerID }) {
            connectedPeerName = opponent.displayName
        }
        
        isConnected = true
        print("✅ [GameKit] Match started with: \(connectedPeerName ?? "Unknown")")
    }
    
    // MARK: - Message Sending
    
    func sendTimerState(timeRemaining: TimeInterval, isRunning: Bool, eggType: String?) {
        let state = FriendTimerState(timeRemaining: timeRemaining, isRunning: isRunning, eggType: eggType)
        sendMessage(type: .timerState, data: state)
    }
    
    func sendEggCracked(eggType: String) {
        sendMessage(type: .eggCracked, data: eggType)
    }
    
    func sendTimerCompleted() {
        sendMessageWithoutData(type: .timerCompleted)
    }
    
    private func sendMessageWithoutData(type: MessageType) {
        guard let match = match, match.expectedPlayerCount == 0 else {
            print("⚠️ [GameKit] No active match to send message")
            return
        }
        
        do {
            let message = Message(type: type, data: nil)
            let encoded = try JSONEncoder().encode(message)
            
            try match.sendData(toAllPlayers: encoded, with: .reliable)
            print("📤 [GameKit] Sent message: \(type.rawValue)")
        } catch {
            print("❌ [GameKit] Failed to send message: \(error)")
        }
    }
    
    private func sendMessage<T: Codable>(type: MessageType, data: T?) {
        guard let match = match, match.expectedPlayerCount == 0 else {
            print("⚠️ [GameKit] No active match to send message")
            return
        }
        
        do {
            var messageData: Data?
            if let data = data {
                messageData = try JSONEncoder().encode(data)
            }
            
            let message = Message(type: type, data: messageData)
            let encoded = try JSONEncoder().encode(message)
            
            try match.sendData(toAllPlayers: encoded, with: .reliable)
            print("📤 [GameKit] Sent message: \(type.rawValue)")
        } catch {
            print("❌ [GameKit] Failed to send message: \(error)")
        }
    }
    
    // MARK: - Message Receiving
    
    private func handleReceivedData(_ data: Data) {
        do {
            let message = try JSONDecoder().decode(Message.self, from: data)
            
            switch message.type {
            case .timerState:
                if let messageData = message.data {
                    let state = try JSONDecoder().decode(FriendTimerState.self, from: messageData)
                    friendTimerState = state
                    friendEggType = state.eggType
                    onFriendTimerUpdated?(state.timeRemaining)
                    print("📥 [GameKit] Received timer state: \(state.timeRemaining)s, running: \(state.isRunning)")
                }
                
            case .eggCracked:
                if let messageData = message.data {
                    do {
                        let eggType = try JSONDecoder().decode(String.self, from: messageData)
                        print("💥 [GameKit] Friend cracked egg: \(eggType)")
                        onFriendCrackedEgg?(eggType)
                    } catch {
                        // Fallback: try as plain string
                        if let eggType = String(data: messageData, encoding: .utf8) {
                            print("💥 [GameKit] Friend cracked egg: \(eggType)")
                            onFriendCrackedEgg?(eggType)
                        }
                    }
                }
                
            case .timerCompleted:
                print("✅ [GameKit] Friend completed timer")
                onFriendTimerCompleted?()
            }
        } catch {
            print("❌ [GameKit] Failed to decode message: \(error)")
        }
    }
}

// MARK: - GKMatchDelegate

extension MultiplayerManager: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            switch state {
            case .connected:
                print("✅ [GameKit] Player connected: \(player.displayName)")
                if !self.isConnected {
                    self.handleMatchStarted(match)
                }
                
            case .disconnected:
                print("❌ [GameKit] Player disconnected: \(player.displayName)")
                if player.playerID == self.match?.players.first(where: { $0.playerID != self.localPlayer.playerID })?.playerID {
                    self.isConnected = false
                    self.connectedPeerName = nil
                    self.friendTimerState = nil
                    self.friendEggType = nil
                }
                
            case .unknown:
                break
                
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        Task { @MainActor [weak self] in
            self?.handleReceivedData(data)
        }
    }
    
    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            print("❌ [GameKit] Match failed: \(error?.localizedDescription ?? "Unknown error")")
            self.disconnect()
        }
    }
    
    nonisolated func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool {
        // Don't automatically reinvite disconnected players
        return false
    }
}

// MARK: - GKMatchmakerViewControllerDelegate

extension MultiplayerManager: GKMatchmakerViewControllerDelegate {
    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.isPresentingMatchmaker = false
            viewController.dismiss(animated: true)
            self.matchmakerViewController = nil
            self.match = match
            match.delegate = self
            self.handleMatchStarted(match)
        }
    }
    
    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFindHostedPlayers players: [GKPlayer]) {
        // Not used for peer-to-peer matches
    }
    
    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, hostedPlayerDidAccept player: GKPlayer) {
        // Not used for peer-to-peer matches
    }
    
    nonisolated func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.isPresentingMatchmaker = false
            viewController.dismiss(animated: true)
            self.matchmakerViewController = nil
            print("🚫 [GameKit] Matchmaking cancelled")
        }
    }
    
    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.isPresentingMatchmaker = false
            let errorDescription = error.localizedDescription
            print("❌ [GameKit] Matchmaking failed: \(errorDescription)")
            
            // Check for specific error about app not being recognized
            if errorDescription.contains("not recognised") || errorDescription.contains("not recognized") {
                self.authenticationError = "App not recognized by Game Center.\n\nPlease complete setup:\n1. Go to App Store Connect\n2. Enable Game Center for your app\n3. Ensure Bundle ID matches\n4. Wait 5-10 minutes for changes to propagate"
            } else {
                self.authenticationError = "Matchmaking failed: \(errorDescription)"
            }
            
            viewController.dismiss(animated: true)
            self.matchmakerViewController = nil
        }
    }
}
