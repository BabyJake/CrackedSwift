//
//  TutorialManager.swift
//  CrackedSwift
//
//  Manages the first-launch interactive tutorial flow.
//  Steps guide new users through: Piggybank explanation → egg selection →
//  instant hatch → Sanctuary → Shop.
//

import Foundation

@MainActor
final class TutorialManager: ObservableObject {
    static let shared = TutorialManager()
    
    // MARK: - Tutorial Steps
    
    enum TutorialStep: Int, CaseIterable {
        case welcome = 0           // "Welcome to Fauna!" — overlay on Home
        case tapNest               // "Tap the nest to choose an egg"
        case showPiggybank         // Highlight Piggybank in egg selection
        case selectEgg             // "Tap a FarmEgg to start!"
        case instantHatch          // Auto-run 0s timer → hatch result
        case showSanctuary         // Navigate to Sanctuary tab
        case showShop              // Navigate to Shop tab
        case complete              // Done
    }
    
    // MARK: - Published State
    
    @Published var currentStep: TutorialStep = .welcome
    @Published var isActive: Bool = false
    
    /// Set to `true` by MenuView when the user taps the nest during `.tapNest`.
    /// ContentView observes this to open the tutorial egg-selection sheet.
    @Published var requestEggSelection: Bool = false
    
    /// Set by ContentView to allow tutorial to switch tabs
    var switchTab: ((Int) -> Void)?
    
    // MARK: - Persistence
    
    private let hasCompletedKey = "FaunaTutorialCompleted"
    private let userDefaults = UserDefaults.standard
    
    var hasCompletedTutorial: Bool {
        get { userDefaults.bool(forKey: hasCompletedKey) }
        set { userDefaults.set(newValue, forKey: hasCompletedKey) }
    }
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Lifecycle
    
    /// Call once when ContentView first appears. Starts the tutorial if the user hasn't done it.
    func startIfNeeded() {
        guard !hasCompletedTutorial else { return }
        currentStep = .welcome
        isActive = true
    }
    
    /// Advance to the next step.
    func next() {
        guard isActive else { return }
        
        let allSteps = TutorialStep.allCases
        guard let idx = allSteps.firstIndex(of: currentStep),
              idx + 1 < allSteps.count else {
            finish()
            return
        }
        
        let nextStep = allSteps[idx + 1]
        currentStep = nextStep
        
        // Side-effects for certain steps
        switch nextStep {
        case .showSanctuary:
            switchTab?(2)    // Sanctuary tab
        case .showShop:
            switchTab?(1)    // Shop tab
        case .complete:
            finish()
        default:
            break
        }
    }
    
    /// Skip / finish the tutorial.
    func finish() {
        isActive = false
        hasCompletedTutorial = true
        switchTab?(0)  // Back to Home
        print("🎓 [Tutorial] Complete")
    }
    
    /// Perform the instant hatch: consume a FarmEgg, hatch an animal, award tutorial coins.
    /// Returns the hatched Animal for display.
    func performInstantHatch() -> Animal? {
        let gameData = GameDataManager.shared
        let animalManager = AnimalManager.shared
        
        // Make sure FarmEgg is selected
        gameData.setCurrentEgg("FarmEgg")
        
        // Consume the egg
        _ = gameData.consumeEgg("FarmEgg")
        
        // Hatch an animal (short study duration → common/uncommon)
        let animal = animalManager.hatchEgg(studyDuration: 60)
        
        // Award tutorial coins (same as a short session)
        let tutorialCoins = 5
        gameData.addCoins(tutorialCoins)
        
        // Clear egg selection so the nest shows empty after
        gameData.clearCurrentEgg()
        
        print("🎓 [Tutorial] Instant hatch: \(animal?.name ?? "nil"), +\(tutorialCoins) coins")
        return animal
    }
}
