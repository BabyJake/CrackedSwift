# CrackedSwift

A focus/study timer app for iOS. Set a timer with an egg; if you leave the app or give up, the egg cracks. Complete the session to hatch an animal and earn coins. Includes a piggybank mode (double coins, no egg) and a sanctuary to view hatched animals.

## Requirements

- Xcode 16+
- iOS 18+
- Physical device recommended for Screen Time and Live Activity

## Getting started

1. Clone the repo and open `CrackedSwift/CrackedSwift.xcodeproj` in Xcode.
2. Select your development team under Signing & Capabilities for the **CrackedSwift** app target and for **CrackedSwiftWidgetExtension** and **DeviceActivityExtension**.
3. Ensure the App Group `group.Cracked.CrackedSwift` is enabled for the main app and the Device Activity Extension (used for leave-app detection).
4. Build and run on a device (or simulator for basic flows).

## Targets

| Target | Purpose |
|--------|---------|
| **CrackedSwift** | Main app (timer, shop, sanctuary) |
| **CrackedSwiftWidgetExtension** | Live Activity / Lock Screen timer |
| **DeviceActivityExtension** | Screen Time–based “left app” detection (egg/piggybank crack or shatter) |

## Leave-app detection

The app uses Apple’s Device Activity (Screen Time) API to tell “left the app” from “locked the phone.” Users choose “Set apps that count as leaving” in the timer screen; if they switch to one of those apps for 5+ seconds, the egg cracks (or piggybank shatters) when they return. Lock screen and quick returns do not. Screen Time authorization is requested on first run.

## Other docs

- `ANIMATION_SETUP.md` – Adding animals/animations  
- `GAMECENTER_SETUP.md` / `GAMEKIT_IMPLEMENTATION.md` – Multiplayer  
- `TESTFLIGHT_DISTRIBUTION.md` – TestFlight  
- `TROUBLESHOOTING.md` – Common issues  

## License

Private / unlicensed unless otherwise noted.
