# Copilot Instructions — CrackedSwift (Fauna)

## Project Overview

iOS focus-timer app (Swift, SwiftUI, iOS 18+). Users start a countdown with an egg; leaving the app cracks it, completing the session hatches an animal. Includes shop, sanctuary grid, CloudKit sync, Live Activities, and Screen Time–based leave detection. Ported from Unity.

## Architecture

**Singleton `ObservableObject` managers** are the core pattern. Every manager is `@MainActor`, uses `static let shared` + `private init()`, and communicates by referencing other managers' `.shared` instances directly — there is no dependency injection.

| Layer | Location | Notes |
|-------|----------|-------|
| Entry point | `CrackedSwiftApp.swift` | Injects `GameDataManager` + `AuthManager` as `@EnvironmentObject`; gates auth flow |
| Managers | `Managers/` | ~15 singletons: `TimerManager`, `ShopManager`, `AnimalManager`, `GridManager`, `CloudKitManager`, `MultiplayerManager` (broken — see below), etc. |
| Models | `Models/` | `GameData` (master Codable struct), `Animal`, `Egg`, `AnimalDatabase` (static registry), `UserProfile`, `TimerAttributes` |
| Views | `Views/` | SwiftUI views; `ContentView` is a `TabView` (Home/Shop/Sanctuary/Leaderboard) |
| Widget | `CrackedSwiftWidget/` | Live Activity lock-screen timer via `TimerAttributes` |
| Extension | `DeviceActivityExtension/` | Screen Time monitor (sets violation flag in App Group UserDefaults) |

## Key Data Flows

- **Persistence**: `GameData` is a single JSON blob in `UserDefaults` (key `"FaunaGameData"`). No SwiftData/CoreData. CloudKit sync pushes to the public database with debounced saves (3s) — on launch it pulls the cloud copy and keeps whichever has more progress. Apple ID stored in Keychain.
- **Timer lifecycle** (`TimerManager`): `startTimer` → consumes egg → starts Live Activity → 1s tick → `timerCompleted` awards coins (5/min, 10/min piggybank) and hatches animal **OR** `giveUpSession` / leave-app creates a grave.
- **Leave-app detection (primary)**: Darwin lock detection via `LockDetectionManager`. On background, a 0.2s delayed check reads `isScreenLocked` (Darwin notification `com.apple.springboard.lockcomplete`). Locked = safe; unlocked = app-switch = crack egg. This is the active mechanism.
- **Leave-app detection (dormant fallback)**: A Device Activity extension exists in `DeviceActivityExtension/` that writes `focusSessionViolated` to App Group UserDefaults. Currently partially commented out — kept as a potential alternative if Darwin detection proves unreliable. Do not remove.

## Conventions & Patterns

- **Resilient Codable decoding**: `GameData.init(from:)` decodes each property individually with `try?` fallbacks. Always follow this pattern when adding new fields — never let a missing key break existing saves.
- **Callback closures on TimerManager**: Views wire `onTimerComplete`, `onEggCracked`, `onCoinsAwarded`, `onPiggybankShattered` closures rather than using Combine publishers.
- **`@EnvironmentObject` vs `.shared`**: `GameDataManager` and `AuthManager` are injected via environment; all other managers are accessed directly as `ManagerName.shared` in views.
- **Design tokens**: Use `AppColors` in `DesignSystem.swift` for all colors (hex-based). Rarity tiers have dedicated colors.
- **MARK sections**: Organize manager files with `// MARK: -` blocks.
- **Print-based logging**: Debug output uses emoji-prefixed `print()` statements (e.g., `🥚`, `🎉`, `💰`).
- **Unity lineage**: Comments like `// Replaces: StudyTimer.cs` reference the original Unity codebase.

## Adding New Features

- **New animal**: Add entry to `AnimalDatabase.allAnimals`, add image to `Assets.xcassets`, then add spawn chance to the relevant `Egg` in `ShopDatabase.default`. See `ADDING_ANIMALS.md`.
- **New manager**: Create as `@MainActor final class FooManager: ObservableObject` with `static let shared` and `private init()`. Reference `GameDataManager.shared` for persistence.
- **New GameData field**: Add property to `GameData`, decode with `self.newField = (try? container.decode(...)) ?? defaultValue` in the resilient decoder, and encode in `encode(to:)`.
- **New view**: Add to `Views/`, access managers via `@StateObject private var mgr = SomeManager.shared` or `@EnvironmentObject` for `GameDataManager`/`AuthManager`.

## Build & Run

```bash
# Open in Xcode (requires Xcode 16+)
open CrackedSwift/CrackedSwift.xcodeproj
```

- Sign all 3 targets (app, widget extension, device activity extension) with your dev team.
- Enable App Group `group.Cracked.CrackedSwift` on main app + extensions.
- Physical device recommended — Screen Time and Live Activities don't work in Simulator.

## Known Issues

- **Multiplayer / Friend Requests**: `MultiplayerManager` (GameKit) has friend-request and co-op matchmaking code but **friend requests are not working**. Treat this feature as broken/in-progress — changes here need manual device testing.

## Key Constants

- App Group: `group.Cracked.CrackedSwift` (defined in `FocusSessionConstants.swift`)
- CloudKit container: `iCloud.Cracked.CrackedSwift`
- UserDefaults game data key: `"FaunaGameData"`
- Coin rates: 5 coins/min (normal), 10 coins/min (piggybank)
- Rarity tiers: common, uncommon, rare, epic, legendary, mythic
