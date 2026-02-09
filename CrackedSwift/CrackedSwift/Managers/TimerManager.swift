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
    
    // MARK: - Lock Detection (Flora-style: distinguish lock from intentional leave)
    
    /// Whether the device was locked while the app was in the background.
    /// Set by `protectedDataWillBecomeUnavailable` notification; persisted to UserDefaults
    /// so it survives app termination.
    private var deviceWasLocked: Bool = false
    private var lockObserver: NSObjectProtocol?
    
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
        
        // Save state (include initialTimerDuration for coin calculation on restore)
        dataManager.saveTimerState(timeRemaining: timeRemaining, wasRunning: true, sessionStartTime: sessionStartTime, activeEggTitle: activeEggTitle, isPiggybankMode: isPiggybankMode, initialTimerDuration: initialTimerDuration)

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
        // Start lock detection so we can distinguish lock-screen from intentional leave
        startLockDetection()
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
        crackEggTask?.cancel()
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
        stopLockDetection()
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
        crackEggTask?.cancel()
        isTimerRunning = false
        stopTimerTick()
        
        // Clear background tracking immediately to prevent false crack detection
        backgroundStartTime = nil
        
        // End Live Activity immediately to avoid widget crash (timerInterval with past endDate can crash)
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
        
        // Update daily streak silently — don't show streak alert while result sheet is presenting
        dataManager.checkAndUpdateStreak(silent: true)
        
        // Clear all state to prevent false crack detection on foreground
        activeEggTitle = nil
        isPiggybankMode = false
        initialTimerDuration = 0
        sessionStartTime = nil
        dataManager.clearTimerState()
        ScreenTimeManager.shared.stopFocusMonitoring()
        stopLockDetection()
        
        print("[CrackedSwift] ✅ Timer completed successfully - all state cleared")
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
            initialTimerDuration = state.initialTimerDuration
            
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
                    
                    // Restore lock detection for the active session.
                    // Re-register the notification observer and read the persisted lock flag
                    // (the notification may have fired before the app was terminated).
                    startLockDetection()
                    deviceWasLocked = UserDefaults.standard.bool(forKey: FocusSessionConstants.deviceWasLockedKey)
                } else {
                    // Timer expired while app was closed - complete it
                    timeRemaining = 0
                    sessionStartTime = startTime
                    isTimerRunning = false
                    // Complete the timer to award coins and handle egg
                    timerCompleted()
                }
            }
        } else {
            // No active timer session to restore — clean up any orphaned Live Activities
            // from a previous app process that were never properly ended.
            LiveActivityManager.shared.endAllActivities()
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
        
        // Restart Screen Time monitoring with remaining time so the schedule covers
        // the rest of the session (the old schedule kept ticking during the break).
        if timeRemaining > 0 {
            ScreenTimeManager.shared.startFocusMonitoring(timerDurationSeconds: timeRemaining)
        }
        
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
    
    // MARK: - Lock Detection
    
    /// Start listening for device-lock notifications (protected data becomes unavailable when
    /// the device locks with a passcode/biometric). Called when a focus session begins.
    private func startLockDetection() {
        stopLockDetection()
        
        deviceWasLocked = false
        UserDefaults.standard.set(false, forKey: FocusSessionConstants.deviceWasLockedKey)
        
        lockObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.activeEggTitle != nil else { return }
                self.deviceWasLocked = true
                UserDefaults.standard.set(true, forKey: FocusSessionConstants.deviceWasLockedKey)
                print("[CrackedSwift] 🔒 Device lock detected (protected data becoming unavailable)")
            }
        }
    }
    
    /// Stop listening for device-lock notifications. Called when a session ends.
    private func stopLockDetection() {
        if let observer = lockObserver {
            NotificationCenter.default.removeObserver(observer)
            lockObserver = nil
        }
        deviceWasLocked = false
        UserDefaults.standard.removeObject(forKey: FocusSessionConstants.deviceWasLockedKey)
    }
    
    // MARK: - Background Handling
    
    func handleAppBecomingInactive() {
        // No-op. Scene-phase–based detection happens in handleAppBackgrounded / handleAppForegrounded.
    }
    
    func handleAppBackgrounded() {
        if isOnBreak { return }
        // Use activeEggTitle instead of isTimerRunning — after app restore
        // isTimerRunning is false but the session is still active.
        guard activeEggTitle != nil else { return }
        
        let bgTime = Date()
        backgroundStartTime = bgTime
        
        // Reset lock detection for this background cycle.
        // The protectedDataWillBecomeUnavailable notification will set it to true
        // if the device locks while we're backgrounded.
        deviceWasLocked = false
        UserDefaults.standard.set(false, forKey: FocusSessionConstants.deviceWasLockedKey)
        
        print("[CrackedSwift] ⏸️ BACKGROUND: App went to background (will detect lock vs. intentional leave on return)")
        dataManager.saveTimerState(timeRemaining: timeRemaining, wasRunning: true, sessionStartTime: sessionStartTime, activeEggTitle: activeEggTitle, isPiggybankMode: isPiggybankMode, backgroundTime: bgTime)
        stopTimerTick()
    }
    
    func handleAppForegrounded() {
        let appState = UIApplication.shared.applicationState
        guard appState == .active else { return }
        
        // ── 1. No active session → nothing to do ──
        if activeEggTitle == nil && timeRemaining == 0 {
            ScreenTimeManager.shared.checkAndClearViolation() // Clear any stale flags
            backgroundStartTime = nil
            print("[CrackedSwift] 🟢 Foreground: No active session, ignoring foreground checks")
            return
        }
        
        // ── 2. Handle break expiry while backgrounded ──
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
        
        // Must have an active session to proceed with crack/resume logic
        guard activeEggTitle != nil else {
            backgroundStartTime = nil
            return
        }
        
        // ── 3. Skip violation check if we never went to background ──
        // If backgroundStartTime is nil, the app went inactive→active (e.g. notification
        // center, Control Center, Siri). Do NOT consume the violation flag here — the
        // Device Activity event fires only once per schedule, so clearing the flag without
        // cracking would waste the one-time trigger and leave the session unprotected.
        guard backgroundStartTime != nil else {
            print("[CrackedSwift] 🟢 Foreground: inactive→active transition (no background), skipping violation check")
            return
        }
        
        // ── 4. Screen Time violation check (primary detection — user used a monitored app) ──
        let hadViolation = ScreenTimeManager.shared.checkAndClearViolation(since: backgroundStartTime)
        
        // Crack immediately if Screen Time confirms user used a monitored app.
        // NOTE: removed isTimerRunning guard — after app restore isTimerRunning is false
        // but the session is still active (activeEggTitle != nil).
        if hadViolation {
            print("[CrackedSwift] 🔴 Foreground: LEFT APP (Screen Time violation) → cracking/shattering")
            if isPiggybankMode {
                shatterPiggybankDueToAppSwitch()
            } else if let eggTitle = activeEggTitle {
                crackEggDueToAppSwitch(eggTitle: eggTitle)
            }
            backgroundStartTime = nil
            return
        }
        
        // ── 5. Flora-style lock vs. intentional leave detection ──
        // When the device LOCKS, iOS makes protected data unavailable — our notification
        // observer sets `deviceWasLocked = true`. If the flag is still false, the user
        // swiped to the home screen or switched to a non-monitored app without locking.
        //
        // Decision matrix:
        //   Device locked          → phone sleep, safe to resume
        //   NOT locked + < grace   → brief accidental leave, safe to resume
        //   NOT locked + ≥ grace   → intentional leave, crack/shatter
        let wasLocked = deviceWasLocked || UserDefaults.standard.bool(forKey: FocusSessionConstants.deviceWasLockedKey)
        let timeInBackground = backgroundStartTime.map { Date().timeIntervalSince($0) } ?? 0
        
        if !wasLocked && timeInBackground >= FocusSessionConstants.homeScreenGracePeriodSeconds {
            // Device was NOT locked and user was away beyond grace period → intentional leave
            print("[CrackedSwift] 🔴 Foreground: device NOT locked, away for \(String(format: "%.1f", timeInBackground))s (≥ \(FocusSessionConstants.homeScreenGracePeriodSeconds)s grace) → cracking/shattering")
            if isPiggybankMode {
                shatterPiggybankDueToAppSwitch()
            } else if let eggTitle = activeEggTitle {
                crackEggDueToAppSwitch(eggTitle: eggTitle)
            }
            backgroundStartTime = nil
            return
        }
        
        if !wasLocked {
            print("[CrackedSwift] 🟡 Foreground: brief leave (\(String(format: "%.1f", timeInBackground))s < grace period) → resuming")
        } else {
            print("[CrackedSwift] 🟢 Foreground: device was locked → resuming (phone sleep)")
        }
        
        // ── 6. Safe scenario → adjust timer for time in background and resume ──
        let capturedBgStart = backgroundStartTime
        
        if timeRemaining > 0 && !isOnBreak {
            if let bgStartTime = backgroundStartTime {
                let elapsed = Date().timeIntervalSince(bgStartTime)
                print("[CrackedSwift] 🟢 Foreground: resuming timer (was in background \(String(format: "%.1f", elapsed))s)")
                timeRemaining = max(0, timeRemaining - elapsed)
            }
            
            if timeRemaining <= 0 {
                timerCompleted()
                backgroundStartTime = nil
                return
            } else {
                isTimerRunning = true
                LiveActivityManager.shared.updateLiveActivity(timeRemaining: timeRemaining, isRunning: true)
                startTimerTick()
                dataManager.saveTimerState(timeRemaining: timeRemaining, wasRunning: true, sessionStartTime: sessionStartTime, activeEggTitle: activeEggTitle, isPiggybankMode: isPiggybankMode, backgroundTime: nil)
            }
        }
        
        backgroundStartTime = nil
        
        // ── 7. Refresh Device Activity monitoring ──
        // Re-start monitoring with the remaining time so the schedule and event are
        // renewed. This guards against iOS silently killing the extension, schedule
        // expiry from timer drift, and ensures the one-time event trigger is fresh.
        if timeRemaining > 0 {
            ScreenTimeManager.shared.startFocusMonitoring(timerDurationSeconds: timeRemaining)
        }
        
        // ── 8. Delayed re-check: catch slow Device Activity extension ──
        // The extension runs in a separate process and may not have set the
        // violation flag by the time we checked above. Re-check after a delay.
        crackEggTask?.cancel()
        crackEggTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            guard !Task.isCancelled, let self = self else { return }
            guard self.activeEggTitle != nil else { return } // Session already ended
            
            let delayedViolation = ScreenTimeManager.shared.checkAndClearViolation(since: capturedBgStart)
            if delayedViolation {
                print("[CrackedSwift] 🔴 Delayed re-check: Screen Time violation detected after 3s → cracking/shattering")
                if self.isPiggybankMode {
                    self.shatterPiggybankDueToAppSwitch()
                } else if let eggTitle = self.activeEggTitle {
                    self.crackEggDueToAppSwitch(eggTitle: eggTitle)
                }
            }
        }
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
        stopLockDetection()
    }
    
    private func shatterPiggybankDueToAppSwitch() {
        crackEggTask?.cancel()
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
        stopLockDetection()
        onPiggybankShattered?()
        onSessionFailed?()
    }
}

