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

The app uses Apple’s Device Activity (Screen Time) API so that **locking the phone** does not crack the egg or shatter the piggybank; only **using another app** does. Users tap “Set apps that count as leaving” on the timer screen and pick which apps to monitor. If they use one of those apps during a focus session, the egg cracks (or piggybank shatters) when they return. Locking the device does not. Screen Time authorization is requested on first run. See **DEVICE_ACTIVITY_SETUP.md** to add the Device Activity Monitor extension target in Xcode.

## Other docs

- `ANIMATION_SETUP.md` – Adding animals/animations  
- `GAMECENTER_SETUP.md` / `GAMEKIT_IMPLEMENTATION.md` – Multiplayer  
- `TESTFLIGHT_DISTRIBUTION.md` – TestFlight  
- `TROUBLESHOOTING.md` – Common issues  

## License

Private / unlicensed unless otherwise noted.
