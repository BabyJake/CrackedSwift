//
//  TimerManager.swift
//  Fauna
//
//  Replaces: StudyTimer.cs
//

import Foundation
import Combine
import UIKit

@MainActor
class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    @Published var timeRemaining: TimeInterval = 0
    @Published var isTimerRunning: Bool = false
    @Published var sessionStartTime: Date?
    @Published var isOnBreak: Bool = false
    @Published var breakTimeRemaining: TimeInterval = 0
    
    private var timer: Timer?
    private var breakTimer: Timer?
    private var crackEggTask: Task<Void, Never>?
    private let dataManager = GameDataManager.shared
    private let animalManager = AnimalManager.shared
    private let shopManager = ShopManager.shared
    private let coinsPerMinute = 5
    
    /// Rate shown in UI (e.g. Shop). Must match coinsPerMinute.
    static let displayCoinsPerMinute: Int = 5
    
    // Track active egg during session
    private var activeEggTitle: String?
    
    // Track if piggybank mode is active (no egg required, just coins)
    private var isPiggybankMode: Bool = false
    
    /// True when the current running session is piggybank (so give-up / app switch will shatter and lose all coins).
    var isCurrentSessionPiggybank: Bool { isPiggybankMode }
    
    // Track initial timer duration for calculating actual study time
    private var initialTimerDuration: TimeInterval = 0
    
    // Track when app went to background for calculating elapsed time (phone sleep)
    private var backgroundStartTime: Date?
    
    // Break constants
    private let breakDuration: TimeInterval = 10 * 60 // 10 minutes
    private let breakCooldown: TimeInterval = 60 * 60 // 1 hour between breaks
    
    // Callbacks
    var onTimerComplete: ((TimeInterval) -> Void)? // Passes study duration in seconds
    var onCoinsAwarded: ((Int) -> Void)?
    var onSessionFailed: (() -> Void)?
    var onEggCracked: ((Animal) -> Void)? // Callback when egg is cracked due to leaving app
    var onPiggybankShattered: (() -> Void)? // Callback when piggybank shatters (app switch or give up) — player loses all coins
    
    private init() {
        restoreTimerState()
        restoreBreakState()
    }
    
    // MARK: - Timer Control
    
    func startTimer(duration: TimeInterval) -> Bool {
        guard !isTimerRunning else { return false }
        
        // Get current egg
        guard let eggTitle = dataManager.getCurrentEgg(),
              dataManager.hasEgg(eggTitle) else {
            // No egg available or selected
            return false
        }
        
        // Check if piggybank mode
        isPiggybankMode = (eggTitle == "Piggybank")
        
        // Consume the egg (piggybank won't actually consume, but we check)
        guard dataManager.consumeEgg(eggTitle) else {
            return false
        }
        
        // Store active egg for potential cracking
        activeEggTitle = eggTitle
        
        timeRemaining = duration
        initialTimerDuration = duration
        isTimerRunning = true
        sessionStartTime = Date()
        
        // Prevent starting timer with 0 or negative duration
        guard duration > 0 else {
            return false
        }
        
        // Save state
        dataManager.saveTimerState(timeRemaining: timeRemaining, wasRunning: true, sessionStartTime: sessionStartTime, activeEggTitle: activeEggTitle, isPiggybankMode: isPiggybankMode)

        // Start Live Activity (Lock Screen / Dynamic Island)
        let eggImageName: String = {
            if eggTitle == "Piggybank" { return "PiggyBank" }
            return shopManager.getEggByTitle(eggTitle)?.imageName ?? eggTitle
        }()
        LiveActivityManager.shared.startLiveActivity(
            eggName: eggTitle,
            eggImageName: eggImageName,
            duration: duration
        )
        
        startTimerTick()
        // Start Screen Time–based leave-app detection so we only crack when user uses another app, not on lock
        ScreenTimeManager.shared.startFocusMonitoring(timerDurationSeconds: duration)
        return true
    }
    
    func pauseTimer() {
        isTimerRunning = false
        stopTimerTick()
        LiveActivityManager.shared.updateLiveActivity(timeRemaining: timeRemaining, isRunning: false)
        dataManager.saveTimerState(timeRemaining: timeRemaining, wasRunning: false, sessionStartTime: sessionStartTime, activeEggTitle: activeEggTitle, isPiggybankMode: isPiggybankMode)
    }
    
    func resumeTimer() {
        guard !isTimerRunning else { return }
        // Don't reset sessionStartTime - preserve the original start time for accurate duration calculation
        // Only set it if it's nil (shouldn't happen, but safety check)
        if sessionStartTime == nil {
            sessionStartTime = Date()
        }
        isTimerRunning = true
        startTimerTick()
        LiveActivityManager.shared.updateLiveActivity(timeRemaining: timeRemaining, isRunning: true)
        dataManager.saveTimerState(timeRemaining: timeRemaining, wasRunning: true, sessionStartTime: sessionStartTime, activeEggTitle: activeEggTitle, isPiggybankMode: isPiggybankMode)
    }
    
    func stopTimer() {
        isTimerRunning = false
        stopTimerTick()
        LiveActivityManager.shared.endLiveActivity()
        timeRemaining = 0
        initialTimerDuration = 0
        sessionStartTime = nil
        activeEggTitle = nil
        
        // End break if active
        if isOnBreak {
            stopBreakTimer()
            isOnBreak = false
            breakTimeRemaining = 0
            dataManager.endBreak()
        }
        
        dataManager.clearTimerState()
        ScreenTimeManager.shared.stopFocusMonitoring()
    }
    
    func resetTimer() {
        stopTimer()
        timeRemaining = 0
    }
    
    // MARK: - Timer Logic
    
    private func startTimerTick() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                    self.dataManager.saveTimerState(timeRemaining: self.timeRemaining, wasRunning: self.isTimerRunning, sessionStartTime: self.sessionStartTime, activeEggTitle: self.activeEggTitle, isPiggybankMode: self.isPiggybankMode)
                } else {
                    self.timerCompleted()
                }
            }
        }
    }
    
    private func stopTimerTick() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timerCompleted() {
        isTimerRunning = false
        stopTimerTick()
        LiveActivityManager.shared.endLiveActivity()
        
        // Calculate actual study duration from session start time
        // This is more reliable than using initialTimerDuration (which might not be restored)
        let actualStudyDuration: TimeInterval
        if let startTime = sessionStartTime {
            actualStudyDuration = Date().timeIntervalSince(startTime)
        } else {
            // Fallback: use initial duration minus remaining time
            actualStudyDuration = max(0, initialTimerDuration - timeRemaining)
        }
        
        let coinsEarned = awardCoinsForSession(completed: true)
        onCoinsAwarded?(coinsEarned)
        
        // Always call onTimerComplete - the handler will check if it's piggybank mode
        // Egg hatching happens in the callback handler (handleTimerComplete in MenuView)
        // Pass the actual study duration for rarity boost calculation
        onTimerComplete?(actualStudyDuration)
        
        activeEggTitle = nil
        isPiggybankMode = false
        initialTimerDuration = 0
        dataManager.clearTimerState()
        ScreenTimeManager.shared.stopFocusMonitoring()
    }
    
    // MARK: - Coins
    
    private func awardCoinsForSession(completed: Bool) -> Int {
        // No partial coins when giving up or leaving app
        guard completed else { return 0 }
        // Base coins on the timer duration you set, not wall-clock time
        let minutes = Int(initialTimerDuration / 60)
        let effectiveCoinsPerMinute = isPiggybankMode ? coinsPerMinute * 2 : coinsPerMinute
        let coinsEarned = max(0, minutes * effectiveCoinsPerMinute)
        if coinsEarned > 0 {
            dataManager.addCoins(coinsEarned)
        }
        return coinsEarned
    }
    
    func giveUpSession() {
        guard isTimerRunning || isOnBreak else { return }
        
        // End break if active
        if isOnBreak {
            stopBreakTimer()
            isOnBreak = false
            breakTimeRemaining = 0
            dataManager.endBreak()
        }
        
        // No coins awarded when giving up
        
        // Piggybank mode: shatter — no give-up coins (nothing to subtract)
        if isPiggybankMode {
            stopTimer()
            LiveActivityManager.shared.endLiveActivity()
            activeEggTitle = nil
            isPiggybankMode = false
            sessionStartTime = nil
            initialTimerDuration = 0
            dataManager.clearTimerState()
            onPiggybankShattered?()
            onSessionFailed?()
            return
        }
        
        // Create grave if not in piggybank mode (similar to app switch)
        if let eggTitle = activeEggTitle {
            let grave = animalManager.createGrave(for: eggTitle)
            onEggCracked?(grave)
        }
        
        stopTimer()
        // stopTimer() already ends the Live Activity, but keep this explicit for safety
        LiveActivityManager.shared.endLiveActivity()
        ScreenTimeManager.shared.stopFocusMonitoring()
        onSessionFailed?()
    }
    
    // MARK: - State Restoration
    
    private func restoreTimerState() {
        if let state = dataManager.restoreTimerState() {
            timeRemaining = state.timeRemaining
            activeEggTitle = state.activeEggTitle
            isPiggybankMode = state.isPiggybankMode
            
            // Adjust for time passed
            if let startTime = state.sessionStartTime {
                // If we have a background time, use that to calculate elapsed time (phone sleep scenario)
                // Otherwise, use session start time (app termination scenario)
                let referenceTime = state.backgroundTime ?? startTime
                let elapsed = Date().timeIntervalSince(referenceTime)
                let adjustedTimeRemaining = timeRemaining - elapsed
                
                if adjustedTimeRemaining > 0 {
                    // Timer still has time remaining - restore state
                    timeRemaining = adjustedTimeRemaining
                    sessionStartTime = startTime
                    // Set background time if it exists
                    backgroundStartTime = state.backgroundTime
                    // Don't auto-resume - let handleAppForegrounded handle it
                    isTimerRunning = false
                } else {
                    // Timer expired while app was closed - complete it
                    timeRemaining = 0
                    sessionStartTime = startTime
                    isTimerRunning = false
                    // Complete the timer to award coins and handle egg
                    timerCompleted()
                }
            }
        }
    }
    
    // MARK: - Break Management
    
    func canTakeBreak() -> Bool {
        guard isTimerRunning && !isOnBreak else { return false }
        
        // Check if enough time has passed since last break
        if let lastBreakTime = dataManager.getLastBreakTime() {
            let timeSinceLastBreak = Date().timeIntervalSince(lastBreakTime)
            return timeSinceLastBreak >= breakCooldown
        }
        
        // No previous break, can take one
        return true
    }
    
    func startBreak() -> Bool {
        guard canTakeBreak() else { return false }
        
        // Pause the main timer
        pauseTimer()
        
        // Start break
        isOnBreak = true
        breakTimeRemaining = breakDuration
        let breakStart = Date()
        dataManager.startBreak(startTime: breakStart)
        
        // Start break countdown timer
        startBreakTimer()
        
        return true
    }
    
    func endBreak() {
        guard isOnBreak else { return }
        
        // Stop break timer
        stopBreakTimer()
        
        // End break
        isOnBreak = false
        breakTimeRemaining = 0
        dataManager.endBreak()
        
        // Resume main timer
        resumeTimer()
    }
    
    private func startBreakTimer() {
        breakTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if self.breakTimeRemaining > 0 {
                    self.breakTimeRemaining -= 1
                    self.dataManager.updateBreakTimeRemaining(self.breakTimeRemaining)
                } else {
                    // Break time expired - auto-end break
                    self.endBreak()
                }
            }
        }
    }
    
    private func stopBreakTimer() {
        breakTimer?.invalidate()
        breakTimer = nil
    }
    
    func formattedBreakTime() -> String {
        let minutes = Int(breakTimeRemaining) / 60
        let seconds = Int(breakTimeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func getTimeUntilBreakAvailable() -> TimeInterval? {
        guard let lastBreakTime = dataManager.getLastBreakTime() else {
            return nil // No previous break, available now
        }
        
        let timeSinceLastBreak = Date().timeIntervalSince(lastBreakTime)
        if timeSinceLastBreak >= breakCooldown {
            return nil // Available now
        }
        
        return breakCooldown - timeSinceLastBreak
    }
    
    private func restoreBreakState() {
        if let breakState = dataManager.restoreBreakState() {
            isOnBreak = breakState.isOnBreak
            breakTimeRemaining = breakState.timeRemaining
            
            if isOnBreak && breakTimeRemaining > 0 {
                // Resume break timer
                startBreakTimer()
            } else if breakTimeRemaining <= 0 && isOnBreak {
                // Break expired while app was closed - end it
                endBreak()
            }
        }
    }
    
    // MARK: - Formatting
    
    func formattedTime() -> String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Background Handling
    
    func handleAppBecomingInactive() {
        // No-op. Screen Time (Device Activity) sets violation when user uses a monitored app.
    }
    
    func handleAppBackgrounded() {
        // Never crack here. Screen Time extension sets a violation flag when user uses another app;
        // we crack only when returning and seeing that flag.
        if isOnBreak { return }
        guard isTimerRunning else { return }
        
        let bgTime = Date()
        backgroundStartTime = bgTime
        print("[CrackedSwift] ⏸️ SLEEP/BACKGROUND: App went to background (timer paused; crack only if Screen Time violation)")
        dataManager.saveTimerState(timeRemaining: timeRemaining, wasRunning: true, sessionStartTime: sessionStartTime, activeEggTitle: activeEggTitle, isPiggybankMode: isPiggybankMode, backgroundTime: bgTime)
        stopTimerTick()
    }
    
    func handleAppForegrounded() {
        let appState = UIApplication.shared.applicationState
        guard appState == .active else { return }
        
        // Check if break expired while app was backgrounded
        if isOnBreak {
            if let breakState = dataManager.restoreBreakState() {
                if breakState.timeRemaining <= 0 {
                    endBreak()
                } else {
                    breakTimeRemaining = breakState.timeRemaining
                    if breakTimer == nil { startBreakTimer() }
                }
            }
        }
        
        // Only crack if: (1) timer was running, (2) we actually went to background, (3) Screen Time violation is set
        let hadViolation = ScreenTimeManager.shared.checkAndClearViolation()
        if isTimerRunning, backgroundStartTime != nil, hadViolation {
            print("[CrackedSwift] 🔴 Foreground: LEFT APP (Screen Time violation while in background) → cracking/shattering")
            if isPiggybankMode {
                shatterPiggybankDueToAppSwitch()
            } else if let eggTitle = activeEggTitle {
                crackEggDueToAppSwitch(eggTitle: eggTitle)
            }
            backgroundStartTime = nil
            return
        }
        if hadViolation && backgroundStartTime == nil {
            print("[CrackedSwift] ⚠️ Foreground: violation flag was set but we never went to background — ignoring (false positive)")
        }
        
        // No violation: resume timer (subtract time spent in background)
        if activeEggTitle != nil && timeRemaining > 0 && !isOnBreak,
           let state = dataManager.restoreTimerState(), state.wasRunning,
           let bgStartTime = backgroundStartTime {
            let elapsed = Date().timeIntervalSince(bgStartTime)
            print("[CrackedSwift] 🟢 Foreground: no violation → resuming timer, elapsed \(String(format: "%.1f", elapsed))s")
            timeRemaining = max(0, timeRemaining - elapsed)
            if timeRemaining <= 0 {
                timerCompleted()
            } else {
                isTimerRunning = true
                LiveActivityManager.shared.updateLiveActivity(timeRemaining: timeRemaining, isRunning: true)
                startTimerTick()
                dataManager.saveTimerState(timeRemaining: timeRemaining, wasRunning: true, sessionStartTime: sessionStartTime, activeEggTitle: activeEggTitle, isPiggybankMode: isPiggybankMode, backgroundTime: nil)
            }
        }
        
        backgroundStartTime = nil
    }
    
    private func crackEggDueToAppSwitch(eggTitle: String) {
        // Cancel any pending crack task
        crackEggTask?.cancel()
        
        // Stop the timer (it might already be paused)
        let wasRunning = isTimerRunning
        isTimerRunning = false
        stopTimerTick()
        LiveActivityManager.shared.endLiveActivity()
        
        // Award partial coins for time spent (only if timer was actually running)
        if wasRunning {
            let coinsEarned = awardCoinsForSession(completed: false)
            onCoinsAwarded?(coinsEarned)
        }
        
        // Only crack egg if not in piggybank mode
        if !isPiggybankMode {
            // Crack the egg - create a grave
            let grave = animalManager.createGrave(for: eggTitle)
            onEggCracked?(grave)
        }
        
        // Clear state
        activeEggTitle = nil
        isPiggybankMode = false
        timeRemaining = 0
        initialTimerDuration = 0
        sessionStartTime = nil
        dataManager.clearTimerState()
        ScreenTimeManager.shared.stopFocusMonitoring()
    }
    
    private func shatterPiggybankDueToAppSwitch() {
        isTimerRunning = false
        stopTimerTick()
        LiveActivityManager.shared.endLiveActivity()
        // No give-up coins — nothing to subtract when piggybank shatters
        activeEggTitle = nil
        isPiggybankMode = false
        timeRemaining = 0
        initialTimerDuration = 0
        sessionStartTime = nil
        dataManager.clearTimerState()
        ScreenTimeManager.shared.stopFocusMonitoring()
        onPiggybankShattered?()
        onSessionFailed?()
    }
}

