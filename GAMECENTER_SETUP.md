# Game Center Setup Guide

This guide walks you through setting up Game Center for multiplayer egg hatching in your CrackedSwift app.

## Prerequisites

- Apple Developer Account (free or paid)
- Xcode installed
- iOS device or simulator (Game Center works on simulator for testing)

---

## Step 1: Enable Game Center in Xcode

### 1.1 Add Game Center Capability

1. Open your project in Xcode
2. Select your **CrackedSwift** target
3. Go to the **Signing & Capabilities** tab
4. Click the **+ Capability** button
5. Search for and add **Game Center**
6. This will automatically:
   - Add Game Center to your entitlements
   - Link the GameKit framework

### 1.2 Verify Entitlements

After adding the capability, check that `CrackedSwift.entitlements` now includes:
```xml
<key>com.apple.developer.game-center</key>
<true/>
```

---

## Step 2: Configure App in App Store Connect

### 2.1 Create App Record (if not already done)

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Sign in with your Apple Developer account
3. Click **My Apps** → **+** → **New App**
4. Fill in:
   - **Platform**: iOS
   - **Name**: CrackedSwift (or your app name)
   - **Primary Language**: English
   - **Bundle ID**: Select your app's bundle ID
   - **SKU**: A unique identifier (e.g., `crackedswift001`)
5. Click **Create**

### 2.2 Enable Game Center for Your App

1. In App Store Connect, select your app
2. Go to **Features** tab
3. Click **Game Center** in the left sidebar
4. Click **Enable Game Center** (if not already enabled)
5. You'll see a message that Game Center is enabled

### 2.3 Create a Leaderboard (Optional but Recommended)

Even if you don't use leaderboards, creating one helps verify Game Center is working:

1. In the **Game Center** section, click **Leaderboards**
2. Click **+** to create a new leaderboard
3. Fill in:
   - **Leaderboard ID**: `egg_hatch_count` (or any unique ID)
   - **Name**: "Eggs Hatched"
   - **Score Format**: Integer
   - **Sort Order**: High to Low
4. Click **Save**

**Note**: You can skip leaderboards if you only want multiplayer features.

---

## Step 3: Configure Bundle ID

### 3.1 Verify Bundle ID

1. In Xcode, select your project
2. Select the **CrackedSwift** target
3. Go to **General** tab
4. Note your **Bundle Identifier** (e.g., `com.yourname.CrackedSwift`)

### 3.2 Ensure Bundle ID Matches App Store Connect

- The Bundle ID in Xcode must match the one in App Store Connect
- If they don't match, either:
  - Change the Bundle ID in Xcode to match App Store Connect, OR
  - Create a new app record in App Store Connect with the correct Bundle ID

---

## Step 4: Testing Setup

### 4.1 Test on Simulator

Game Center works on iOS Simulator, but with limitations:

1. Open **Settings** app on simulator
2. Scroll down to **Game Center**
3. Sign in with a test Apple ID (or create one)
4. Your app can now test Game Center features

### 4.2 Test on Physical Device

For full testing, use a physical device:

1. Connect your iOS device
2. In Xcode, select your device as the run destination
3. Make sure you're signed in to Game Center on the device:
   - Settings → Game Center
   - Sign in with your Apple ID

### 4.3 Sandbox vs Production

- **Sandbox**: For testing during development
  - Use test Apple IDs
  - Automatically used when testing from Xcode
- **Production**: For App Store builds
  - Uses real Game Center accounts
  - Only works after app is published (or TestFlight)

---

## Step 5: Code Implementation Requirements

After setup, your code will need to:

1. **Authenticate the local player**:
   ```swift
   GKLocalPlayer.local.authenticateHandler = { viewController, error in
       // Handle authentication
   }
   ```

2. **Create a match** (for multiplayer):
   ```swift
   let request = GKMatchRequest()
   request.minPlayers = 2
   request.maxPlayers = 2
   // Create match
   ```

3. **Send/receive data**:
   ```swift
   match.sendData(toAllPlayers: data, with: .reliable)
   ```

---

## Step 6: Common Issues & Solutions

### Issue: "Game Center is not enabled for this app"

**Solution**:
- Verify Game Center capability is added in Xcode
- Check that Game Center is enabled in App Store Connect
- Ensure Bundle ID matches between Xcode and App Store Connect

### Issue: "Player is not authenticated"

**Solution**:
- Sign in to Game Center in Settings app
- Make sure you're using a valid Apple ID
- For testing, use Sandbox environment

### Issue: "Cannot find match"

**Solution**:
- Ensure both devices are signed into Game Center
- Check network connectivity
- Verify both devices are using the same environment (Sandbox or Production)

### Issue: "App not found in Game Center"

**Solution**:
- App must be created in App Store Connect first
- Bundle ID must match exactly
- May take a few minutes to propagate after creation

---

## Step 7: Testing Checklist

Before implementing the code, verify:

- [ ] Game Center capability added in Xcode
- [ ] App created in App Store Connect
- [ ] Game Center enabled in App Store Connect
- [ ] Bundle ID matches in both places
- [ ] Signed in to Game Center on test device/simulator
- [ ] Can see your app in Game Center (Settings → Game Center → Your Apps)

---

## Step 8: Development vs Production

### Development (Current)
- Use Sandbox environment automatically
- Test with any Apple ID
- Works immediately after setup
- Limited to 100 test users

### Production (App Store)
- Requires app to be submitted to App Store
- Or use TestFlight for beta testing
- Uses real Game Center accounts
- No user limit

---

## Next Steps

Once setup is complete:

1. I'll implement the GameKit multiplayer code
2. Test authentication flow
3. Test matchmaking between two devices
4. Test real-time data synchronization
5. Test egg cracking synchronization

---

## Quick Reference

**App Store Connect**: https://appstoreconnect.apple.com
**Game Center Documentation**: https://developer.apple.com/documentation/gamekit
**Bundle ID Location**: Xcode → Target → General → Bundle Identifier
**Capability Location**: Xcode → Target → Signing & Capabilities → + Capability

---

## Important Notes

1. **You don't need to submit to App Store** to test Game Center - Sandbox works for development
2. **Two devices needed** for full multiplayer testing
3. **Same Apple ID** can't test multiplayer - need two different accounts
4. **Simulator works** but physical devices are more reliable
5. **Network required** - Game Center works over internet, not just local network

---

Ready to proceed? Once you've completed the setup steps above, let me know and I'll implement the GameKit multiplayer code!


