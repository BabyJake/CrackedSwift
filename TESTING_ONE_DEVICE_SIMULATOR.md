# Testing Game Center Multiplayer: One Device + Simulator

This guide explains how to test the multiplayer feature using one physical iOS device and one iOS Simulator.

## Prerequisites

✅ **Two different Apple IDs** (required - Game Center won't match the same account)
✅ **Game Center setup completed** (see GAMECENTER_SETUP.md)
✅ **Xcode installed**
✅ **Physical iOS device** (iPhone or iPad)
✅ **Mac with Xcode** (for simulator)

---

## Step 1: Prepare Your Apple IDs

You need **two different Apple IDs**:

1. **Apple ID #1** - For your physical device
2. **Apple ID #2** - For the simulator

**Important**: 
- These must be **different accounts**
- Both must have Game Center enabled
- You can create test accounts at https://appleid.apple.com

---

## Step 2: Sign Into Game Center on Physical Device

1. On your **physical iOS device**:
   - Open **Settings** app
   - Scroll down to **Game Center**
   - Tap **Sign In**
   - Enter **Apple ID #1** credentials
   - Verify you're signed in (should see your name)

2. **Verify**:
   - Settings → Game Center should show your name
   - You can open the Game Center app to confirm

---

## Step 3: Sign Into Game Center on Simulator

### Option A: Via Settings (Recommended)

1. **Launch Simulator**:
   - Open Xcode
   - Xcode → Open Developer Tool → Simulator
   - Or: Product → Destination → Choose a simulator

2. **Open Settings**:
   - In simulator, open **Settings** app
   - Scroll to **Game Center**
   - Tap **Sign In**
   - Enter **Apple ID #2** credentials
   - Verify you're signed in

### Option B: Via Game Center App

1. In simulator, open **Game Center** app
2. Sign in with **Apple ID #2**
3. Verify authentication

**Note**: Simulator may show "Sandbox" environment - this is normal for development.

---

## Step 4: Build and Run on Both

### On Physical Device:

1. **Connect device** to Mac via USB
2. **In Xcode**:
   - Select your device as the run destination
   - Product → Destination → Your Device Name
3. **Run the app** (⌘R)
4. **Verify**:
   - App should show "Connected" or your Game Center name
   - Check console logs for: `✅ [GameKit] Player authenticated: [Your Name]`

### On Simulator:

1. **In Xcode**:
   - Select a simulator as the run destination
   - Product → Destination → iPhone 15 (or any simulator)
2. **Run the app** (⌘R) - **in a separate Xcode window or instance**
   - Or: Use Xcode's ability to run multiple instances
3. **Verify**:
   - App should show "Connected" or your Game Center name
   - Check console logs for authentication

**Tip**: You can run both from the same Xcode project by:
- Opening the project twice
- Or using Xcode's scheme manager to run multiple instances

---

## Step 5: Test Matchmaking

### Method 1: Quick Match (Easiest)

**On Device**:
1. Open the app
2. Tap **"Connect"** button
3. Tap **"Quick Match"**
4. Wait for match (may take 30-60 seconds)

**On Simulator**:
1. Open the app (should be running)
2. Tap **"Connect"** button
3. Tap **"Quick Match"**
4. Wait for match

**Expected Result**:
- Both should find each other within 30-60 seconds
- Connection status should show friend's name
- You can now test egg hatching together

### Method 2: Friend Invite (More Complex)

**On Device**:
1. Open the app
2. Tap **"Connect"** → **"Find a Friend"**
3. Game Center UI appears
4. Tap **"Invite Friends"**
5. Select the friend (Apple ID #2) if they're in your friends list
6. Send invitation

**On Simulator**:
1. Should receive invitation notification
2. Accept invitation
3. Match should start

**Note**: Friend invites require the accounts to be Game Center friends first.

---

## Step 6: Test Multiplayer Features

Once connected:

### Test Timer Synchronization:
1. **Device**: Start a timer (e.g., 5 minutes)
2. **Simulator**: Should see friend's timer state updating
3. **Simulator**: Start your own timer
4. **Device**: Should see friend's timer state

### Test Egg Cracking:
1. **Device**: Start a timer
2. **Simulator**: Start a timer
3. **Device**: Tap "Give Up" (cracks your egg)
4. **Simulator**: Should automatically crack your egg too! ✅
5. Both should see graves in sanctuary

### Test Timer Completion:
1. **Device**: Start a short timer (1 minute for testing)
2. **Simulator**: Start a timer
3. **Device**: Wait for timer to complete
4. **Simulator**: Should see notification that friend completed

---

## Troubleshooting

### "Cannot find match"

**Possible causes**:
- Both using same Apple ID (must be different!)
- One not signed into Game Center
- Network connectivity issues
- App not recognized (complete setup first)

**Solutions**:
1. Verify both are signed in with **different** Apple IDs
2. Check Settings → Game Center on both
3. Try Quick Match instead of friend invites
4. Wait 30-60 seconds (matchmaking takes time)
5. Restart both apps

### "Player not authenticated"

**On Device**:
- Settings → Game Center → Sign in
- Restart app

**On Simulator**:
- Settings → Game Center → Sign in
- May need to restart simulator
- Check that simulator is running iOS 13+ (Game Center requirement)

### "App not recognized"

- Complete Game Center setup in App Store Connect first
- Wait 5-10 minutes after setup
- Verify Bundle ID matches

### Simulator-Specific Issues

**"Game Center not available"**:
- Some older simulators don't support Game Center
- Use iOS 13+ simulator
- Try iPhone 14/15 simulator

**"Can't sign in"**:
- Simulator may need internet connection
- Check Mac's network connection
- Try signing out and back in

**"Sandbox environment"**:
- This is normal for development
- Simulator often shows "Sandbox" - this is fine
- Both device and simulator should use Sandbox for testing

---

## Quick Testing Checklist

Before starting:
- [ ] Two different Apple IDs ready
- [ ] Device signed into Game Center (Apple ID #1)
- [ ] Simulator signed into Game Center (Apple ID #2)
- [ ] App running on device
- [ ] App running on simulator
- [ ] Both show authenticated in logs
- [ ] Game Center setup completed in App Store Connect

Testing flow:
- [ ] Both tap "Connect" → "Quick Match"
- [ ] Wait 30-60 seconds
- [ ] Connection established (see friend's name)
- [ ] Start timers on both
- [ ] Verify timer states sync
- [ ] Test egg cracking (one cracks → both crack)
- [ ] Test timer completion

---

## Tips for Faster Testing

1. **Use Quick Match** - Faster than friend invites
2. **Short timers** - Use 1-2 minute timers for quick testing
3. **Check logs** - Xcode console shows connection status
4. **Keep both visible** - Have device and simulator side-by-side
5. **Network** - Ensure both are on same network (device on WiFi, Mac on WiFi)

---

## Alternative: Two Simulators

If you don't have a physical device, you can test with **two simulators**:

1. **Open two simulator instances**:
   - Xcode → Window → Devices and Simulators
   - Create two different simulators
   - Or use same simulator type twice

2. **Sign in with different Apple IDs** on each

3. **Run app on both**:
   - Use Xcode's ability to run multiple schemes
   - Or open project twice

4. **Test same way** as device + simulator

**Note**: Two simulators on same Mac may have network limitations, but should work for basic testing.

---

## Expected Console Output

**Device (Apple ID #1)**:
```
✅ [GameKit] Player authenticated: YourName1
📤 [GameKit] Sent message: timerState
📥 [GameKit] Received timer state: 300.0s, running: true
💥 [GameKit] Friend cracked egg: CommonEgg
```

**Simulator (Apple ID #2)**:
```
✅ [GameKit] Player authenticated: YourName2
📤 [GameKit] Sent message: timerState
📥 [GameKit] Received timer state: 300.0s, running: true
💥 [GameKit] Friend cracked egg: CommonEgg
```

---

## Next Steps

Once basic testing works:
1. Test with two physical devices (more reliable)
2. Test friend invites (requires Game Center friends)
3. Test edge cases (disconnections, network issues)
4. Test with different timer durations
5. Test multiple egg types

---

## Common Questions

**Q: Can I use the same Apple ID?**
A: No, Game Center requires different accounts for multiplayer.

**Q: Why is matchmaking slow?**
A: Game Center needs time to find players. 30-60 seconds is normal.

**Q: Simulator shows "Sandbox" - is that OK?**
A: Yes, Sandbox is normal for development testing.

**Q: Can I test without App Store Connect setup?**
A: No, the app must be recognized by Game Center first.

**Q: Matchmaker won't show on simulator?**
A: Check iOS version (needs 13+), try restarting simulator.

---

Good luck testing! 🎮


