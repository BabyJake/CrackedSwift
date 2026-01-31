//
//  SoundManager.swift
//  CrackedSwift
//
//  Handles all sound effects in the game
//

import AVFoundation
import Foundation
import UIKit

@MainActor
class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    @Published var isSoundEnabled: Bool = true
    @Published var volume: Float = 1.0
    
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    
    // Sound effect file names
    enum SoundEffect: String {
        case catMeow = "cat-meow-297927"
        
        var fileExtension: String {
            return "mp3"
        }
    }
    
    private init() {
        // Load user preferences
        isSoundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        if UserDefaults.standard.object(forKey: "soundVolume") != nil {
            volume = UserDefaults.standard.float(forKey: "soundVolume")
        } else {
            // Default to enabled if not set
            isSoundEnabled = true
        }
    }
    
    // MARK: - Play Sound Effects
    
    func play(_ sound: SoundEffect) {
        guard isSoundEnabled else { return }
        
        // Check if player already exists
        if let player = audioPlayers[sound.rawValue] {
            player.currentTime = 0
            player.volume = volume
            player.play()
            return
        }
        
        // Try to load from asset catalog dataset first
        if let dataAsset = NSDataAsset(name: sound.rawValue) {
            do {
                let player = try AVAudioPlayer(data: dataAsset.data)
                player.volume = volume
                player.prepareToPlay()
                audioPlayers[sound.rawValue] = player
                player.play()
                return
            } catch {
                print("⚠️ [SoundManager] Failed to create player from data asset: \(error)")
            }
        }
        
        // Fallback: Try to load from bundle
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: sound.fileExtension) else {
            print("⚠️ [SoundManager] Sound file not found: \(sound.rawValue).\(sound.fileExtension)")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = volume
            player.prepareToPlay()
            audioPlayers[sound.rawValue] = player
            player.play()
        } catch {
            print("❌ [SoundManager] Failed to play sound \(sound.rawValue): \(error)")
        }
    }
    
    // MARK: - Settings
    
    func setSoundEnabled(_ enabled: Bool) {
        isSoundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "soundEnabled")
    }
    
    func setVolume(_ newVolume: Float) {
        volume = max(0.0, min(1.0, newVolume))
        UserDefaults.standard.set(volume, forKey: "soundVolume")
        
        // Update all existing players
        for player in audioPlayers.values {
            player.volume = volume
        }
    }
    
    // MARK: - Stop All Sounds
    
    func stopAll() {
        for player in audioPlayers.values {
            player.stop()
            player.currentTime = 0
        }
    }
}

