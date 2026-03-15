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
    
    // #region agent log helper
    private func logDebug(_ location: String, _ message: String, _ data: [String: Any] = [:]) {
        let logPath = "/Users/jacobtaylor/Desktop/CrackedSwift/.cursor/debug.log"
        let logEntry: [String: Any] = [
            "location": location,
            "message": message,
            "data": data,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: logEntry),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let logLine = jsonString + "\n"
            if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(logLine.data(using: .utf8)!)
                fileHandle.closeFile()
            } else {
                // File doesn't exist, create it
                let fileManager = FileManager.default
                let directory = (logPath as NSString).deletingLastPathComponent
                try? fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
                try? logLine.write(toFile: logPath, atomically: false, encoding: .utf8)
            }
        }
    }
    // #endregion
    
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
    
    // MARK: - Flora-style Lock vs. Leave Detection
    
    /// Set to `true` by the 0.2 s delayed check in handleAppBackgrounded() when the device
    /// was NOT locked (i.e. user intentionally left). Read by handleAppForegrounded().
    private var appSwitchDetected: Bool = false
    
    /// Pending background work item for the 0.2 s delayed lock check.
    private var backgroundCheckWorkItem: DispatchWorkItem?
    
    /// Background task identifier so iOS keeps us alive for the 0.2 s check.
    private var bgTaskId: UIBackgroundTaskIdentifier = .invalid
    
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
        // Screen Time monitoring commented out — using Darwin lock detection instead (Flora-style).
        // ScreenTimeManager.shared.startFocusMonitoring(timerDurationSeconds: duration)
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
        // ScreenTimeManager.shared.stopFocusMonitoring()
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
        
        // Record actual study time for statistics
        dataManager.addStudyTime(actualStudyDuration)
        
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
        // ScreenTimeManager.shared.stopFocusMonitoring()
        
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
            
            // Notify friends about the cracked egg
            Task {
                await CrackNotificationManager.shared.notifyFriendsOfCrack(eggType: eggTitle)
            }
        }
        
        stopTimer()
        // stopTimer() already ends the Live Activity, but keep this explicit for safety
        LiveActivityManager.shared.endLiveActivity()
        // ScreenTimeManager.shared.stopFocusMonitoring()
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
                
                // #region agent log
                logDebug("TimerManager.swift:312", "restoreTimerState calculating elapsed", [
                    "timeRemaining": timeRemaining,
                    "elapsed": elapsed,
                    "adjustedTimeRemaining": adjustedTimeRemaining,
                    "hasBackgroundTime": state.backgroundTime != nil
                ])
                // #endregion
                
                if adjustedTimeRemaining > 0 {
                    // Timer still has time remaining - restore state
                    timeRemaining = adjustedTimeRemaining
                    sessionStartTime = startTime
                    // Set background time if it exists
                    backgroundStartTime = state.backgroundTime
                    // Don't auto-resume - let handleAppForegrounded handle it
                    isTimerRunning = false
                    
                    // LockDetectionManager is a singleton that registers on init;
                    // no extra setup needed. The Darwin flag from before termination
                    // is lost, but handleAppForegrounded() will still run and check
                    // the live Darwin flag (covers the lock-then-relaunch case).
                    // #region agent log
                    logDebug("TimerManager.swift:329", "Timer restored with time remaining", ["timeRemaining": timeRemaining])
                    // #endregion
                } else {
                    // Timer expired while app was closed - complete it
                    // #region agent log
                    logDebug("TimerManager.swift:335", "Timer expired during restore - completing", ["elapsed": elapsed])
                    // #endregion
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
        
        // Screen Time monitoring commented out — using Darwin lock detection instead.
        // if timeRemaining > 0 {
        //     ScreenTimeManager.shared.startFocusMonitoring(timerDurationSeconds: timeRemaining)
        // }
        
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
    
    // MARK: - Background Task Helpers
    
    private func endBackgroundTask() {
        if bgTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(bgTaskId)
            bgTaskId = .invalid
        }
    }
    
    /// Called when the delayed background check confirms the user left intentionally.
    private func didDetectAppSwitch() {
        if isPiggybankMode {
            shatterPiggybankDueToAppSwitch()
        } else if let eggTitle = activeEggTitle {
            crackEggDueToAppSwitch(eggTitle: eggTitle)
        }
    }
    
    // MARK: - Background Handling
    
    func handleAppBecomingInactive() {
        // No-op for now.
        // Notification Center / Control Center only move the app to .inactive (not .background),
        // so handleAppBackgrounded() won't fire and the user won't be penalised.
    }
    
    func handleAppBackgrounded() {
        if isOnBreak { return }
        // Use activeEggTitle instead of isTimerRunning — after app restore
        // isTimerRunning is false but the session is still active.
        guard activeEggTitle != nil else { return }
        
        let bgTime = Date()
        backgroundStartTime = bgTime
        appSwitchDetected = false
        
        print("[CrackedSwift] ⏸️ BACKGROUND: App went to background (checking lock vs. leave…)")
        dataManager.saveTimerState(timeRemaining: timeRemaining, wasRunning: true, sessionStartTime: sessionStartTime, activeEggTitle: activeEggTitle, isPiggybankMode: isPiggybankMode, backgroundTime: bgTime)
        stopTimerTick()
        
        // ── Delayed lock check (Flora-style) ──
        // Request background execution so the 0.2 s delay actually fires before iOS suspends us.
        bgTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // After 0.2 s, read the Darwin lock flag set by LockDetectionManager.
        // If the device locked (side button / auto-lock) the flag is already true.
        // If the user just swiped home, the flag is still false → app switch.
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.activeEggTitle != nil else {
                    self?.endBackgroundTask()
                    return
                }
                
                if LockDetectionManager.shared.isScreenLocked {
                    self.appSwitchDetected = false
                    print("[CrackedSwift] 🔒 Background check (0.2 s): device locked → safe (phone sleep)")
                } else {
                    self.appSwitchDetected = true
                    print("[CrackedSwift] 🔴 Background check (0.2 s): device NOT locked → app switch detected")
                }
                
                self.endBackgroundTask()
            }
        }
        backgroundCheckWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
    
    func handleAppForegrounded() {
        let appState = UIApplication.shared.applicationState
        guard appState == .active else { return }
        
        // ── Read & reset the Darwin lock flag BEFORE any early returns ──
        // This must happen first so the flag is consumed exactly once per cycle.
        let wasLockedDuringBackground = LockDetectionManager.shared.isScreenLocked
        LockDetectionManager.shared.resetLockState()
        
        // Cancel any pending 0.2 s background check (we'll use its result or fall back)
        backgroundCheckWorkItem?.cancel()
        backgroundCheckWorkItem = nil
        endBackgroundTask()
        
        // #region agent log
        logDebug("TimerManager.swift:532", "handleAppForegrounded entry", [
            "activeEggTitle": activeEggTitle ?? "nil",
            "timeRemaining": timeRemaining,
            "backgroundStartTime": backgroundStartTime?.timeIntervalSince1970 ?? 0,
            "wasLockedDuringBackground": wasLockedDuringBackground,
            "appSwitchDetected": appSwitchDetected
        ])
        // #endregion
        
        // ── 1. No active session → nothing to do ──
        if activeEggTitle == nil && timeRemaining == 0 {
            backgroundStartTime = nil
            appSwitchDetected = false
            print("[CrackedSwift] 🟢 Foreground: No active session, ignoring")
            // #region agent log
            logDebug("TimerManager.swift:547", "No active session early return", [:])
            // #endregion
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
            appSwitchDetected = false
            return
        }
        
        // ── 3. Skip if we never went to background ──
        // Notification Center / Control Center only move the app to .inactive,
        // so backgroundStartTime stays nil → no penalty.
        guard backgroundStartTime != nil else {
            print("[CrackedSwift] 🟢 Foreground: inactive→active (Notification Center / Control Center), skipping")
            // #region agent log
            logDebug("TimerManager.swift:576", "Never went to background early return", [:])
            // #endregion
            return
        }
        
        // ── 3.5. CRITICAL: Check if timer expired naturally BEFORE crack logic ──
        // If timer expired while backgrounded (phone locked/turned off), complete it without cracking
        if let bgStartTime = backgroundStartTime {
            let elapsed = Date().timeIntervalSince(bgStartTime)
            let adjustedTimeRemaining = timeRemaining - elapsed
            
            // #region agent log
            logDebug("TimerManager.swift:583", "Checking timer expiry before crack logic", [
                "timeRemaining": timeRemaining,
                "elapsed": elapsed,
                "adjustedTimeRemaining": adjustedTimeRemaining,
                "wasLockedDuringBackground": wasLockedDuringBackground,
                "appSwitchDetected": appSwitchDetected
            ])
            // #endregion
            
            if adjustedTimeRemaining <= 0 {
                // Timer expired naturally - complete it without cracking
                print("[CrackedSwift] ✅ Foreground: Timer expired while backgrounded (elapsed: \(String(format: "%.1f", elapsed))s) → completing without crack")
                // #region agent log
                logDebug("TimerManager.swift:591", "Timer expired naturally - completing", ["elapsed": elapsed])
                // #endregion
                timeRemaining = 0
                timerCompleted()
                backgroundStartTime = nil
                appSwitchDetected = false
                return
            }
        }
        
        // ── 4. Flora-style lock vs. intentional leave ──
        //
        // Decision logic (three signals, checked in priority order):
        //   a) appSwitchDetected == true   → 0.2 s check confirmed: NOT locked → CRACK
        //   b) wasLockedDuringBackground   → Darwin notification fired → phone sleep → SAFE
        //   c) neither flag set            → user returned before 0.2 s check could run
        //                                    AND no Darwin lock notification → CRACK
        //
        // Case (c) catches very fast home-swipe-and-return (< 0.2 s).
        // A legitimate quick lock/unlock (< 0.2 s) is physically impossible because the
        // user must authenticate (Face ID / passcode) to return, which takes longer.
        
        let shouldCrack: Bool
        if appSwitchDetected {
            // Background check ran and confirmed no lock → app switch
            shouldCrack = true
        } else if wasLockedDuringBackground {
            // Darwin notification fired → device was locked → safe
            shouldCrack = false
        } else {
            // Neither flag set → no lock detected, user left intentionally
            // BUT: If app was terminated (phone turned off), backgroundStartTime exists but
            // Darwin notification never fired. Check if elapsed time suggests phone was off.
            // If elapsed time is very long (> 1 hour), likely phone was turned off, not app switch.
            if let bgStartTime = backgroundStartTime {
                let elapsed = Date().timeIntervalSince(bgStartTime)
                // If more than 1 hour passed, assume phone was turned off (safe)
                if elapsed > 3600 {
                    shouldCrack = false
                    // #region agent log
                    logDebug("TimerManager.swift:620", "Long elapsed time - assuming phone turned off", ["elapsed": elapsed])
                    // #endregion
                } else {
                    shouldCrack = true
                }
            } else {
                shouldCrack = true
            }
        }
        
        // #region agent log
        logDebug("TimerManager.swift:630", "Crack decision", [
            "shouldCrack": shouldCrack,
            "appSwitchDetected": appSwitchDetected,
            "wasLockedDuringBackground": wasLockedDuringBackground
        ])
        // #endregion
        
        if shouldCrack {
            print("[CrackedSwift] 🔴 Foreground: user left app (appSwitchDetected=\(appSwitchDetected), locked=\(wasLockedDuringBackground)) → cracking/shattering")
            // #region agent log
            logDebug("TimerManager.swift:636", "Cracking egg due to app switch", [:])
            // #endregion
            didDetectAppSwitch()
            backgroundStartTime = nil
            appSwitchDetected = false
            return
        }
        
        print("[CrackedSwift] 🟢 Foreground: device was locked → resuming (phone sleep)")
        
        // ── 5. Safe: device was locked → adjust timer for background time and resume ──
        if timeRemaining > 0 && !isOnBreak {
            if let bgStartTime = backgroundStartTime {
                let elapsed = Date().timeIntervalSince(bgStartTime)
                print("[CrackedSwift] 🟢 Foreground: resuming timer (was in background \(String(format: "%.1f", elapsed))s)")
                timeRemaining = max(0, timeRemaining - elapsed)
                // #region agent log
                logDebug("TimerManager.swift:650", "Resuming timer after lock", [
                    "timeRemaining": timeRemaining,
                    "elapsed": elapsed
                ])
                // #endregion
            }
            
            if timeRemaining <= 0 {
                // Timer expired during background (but we already checked above, this is safety)
                timerCompleted()
                backgroundStartTime = nil
                appSwitchDetected = false
                return
            } else {
                isTimerRunning = true
                LiveActivityManager.shared.updateLiveActivity(timeRemaining: timeRemaining, isRunning: true)
                startTimerTick()
                dataManager.saveTimerState(timeRemaining: timeRemaining, wasRunning: true, sessionStartTime: sessionStartTime, activeEggTitle: activeEggTitle, isPiggybankMode: isPiggybankMode, backgroundTime: nil)
            }
        }
        
        backgroundStartTime = nil
        appSwitchDetected = false
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
            
            // Notify friends about the cracked egg
            Task {
                await CrackNotificationManager.shared.notifyFriendsOfCrack(eggType: eggTitle)
            }
        }
        
        // Clear state
        activeEggTitle = nil
        isPiggybankMode = false
        timeRemaining = 0
        initialTimerDuration = 0
        sessionStartTime = nil
        dataManager.clearTimerState()
        // ScreenTimeManager.shared.stopFocusMonitoring()
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
        // ScreenTimeManager.shared.stopFocusMonitoring()
        onPiggybankShattered?()
        onSessionFailed?()
    }
}

