# Device Activity Extension

Leave-app detection uses Apple’s Screen Time (Device Activity) API so that **locking the phone** does not crack the egg/shatter the piggybank; only **using another app** does.

The extension target is in `DeviceActivityExtension/` and is already embedded in the main app. Verify the following in Xcode:

1. **DeviceActivityExtension target → Signing & Capabilities**
   - **App Groups**: `group.Cracked.CrackedSwift` (same as main app). If missing, click **+ Capability** → App Groups → add `group.Cracked.CrackedSwift`.
   - **Family Controls (Distribution)** must be present (required for Screen Time). If you see “development only” warnings, ensure this target has **Family Controls (Distribution)**—not **Family Controls (Development)**—and that the extension’s bundle ID (`Cracked.CrackedSwift.DeviceActivityExtension`) is included in your Apple Developer Family Controls (Distribution) request.

2. **Main app target (CrackedSwift) → Signing & Capabilities**
   - **App Groups**: `group.Cracked.CrackedSwift` must be enabled.

3. **Build**
   - Build the main app scheme; the extension is built and embedded automatically.
   - Test on a **physical device** (Screen Time / Device Activity are unreliable in the simulator).

When the user has chosen “Set apps that count as leaving” and starts a focus session, the app uses Screen Time to monitor those apps. If the user uses one of them, the extension sets a flag and the egg/piggybank cracks when they return. Locking the device does not set the flag.
