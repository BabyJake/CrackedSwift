# Troubleshooting Game Center Multiplayer

## Error: "App not recognised by Game Center"

This is the most common error when setting up Game Center. Here's how to fix it:

### Step 1: Verify App Store Connect Setup

1. **Go to App Store Connect**: https://appstoreconnect.apple.com
2. **Sign in** with your Apple Developer account
3. **Find your app** (or create it if it doesn't exist)
4. **Check Bundle ID**:
   - In App Store Connect: Go to your app → App Information → Bundle ID
   - In Xcode: Target → General → Bundle Identifier
   - **They must match exactly**

### Step 2: Enable Game Center

1. In App Store Connect, go to your app
2. Click **Features** tab (left sidebar)
3. Click **Game Center** in the list
4. Click **Enable Game Center** (if not already enabled)
5. You should see "Game Center is enabled for this app"

### Step 3: Verify Xcode Setup

1. Open your project in Xcode
2. Select your **target** (CrackedSwift)
3. Go to **Signing & Capabilities** tab
4. Verify **Game Center** capability is added
5. If not, click **+ Capability** and add it

### Step 4: Wait for Propagation

After enabling Game Center in App Store Connect:
- **Wait 5-10 minutes** for changes to propagate
- Game Center servers need time to recognize your app
- Try again after waiting

### Step 5: Verify Bundle ID Match

**Critical**: The Bundle ID must match exactly in both places:

**Xcode**:
```
Target → General → Bundle Identifier
Example: com.yourname.CrackedSwift
```

**App Store Connect**:
```
App → App Information → Bundle ID
Must be exactly the same
```

### Step 6: Test Again

1. Close and reopen the app
2. Check that you're authenticated (should see your Game Center name)
3. Try "Find a Friend" again

---

## Error: "Attempt to present ... which is already presenting"

This means the matchmaker view controller is trying to show when another view is already visible.

**Fixed in code**: The app now checks for existing presentations before showing the matchmaker.

**If you still see this**:
1. Dismiss any open sheets/modals
2. Try again
3. Restart the app if needed

---

## Error: "Player not authenticated"

**Solution**:
1. Go to **Settings** app on your device
2. Scroll to **Game Center**
3. **Sign in** with your Apple ID
4. Return to the app
5. Tap "Retry Authentication" if shown

---

## Error: "Cannot find match"

**Possible causes**:
1. **No other players online** - Game Center needs at least 2 players
2. **Network issues** - Check internet connection
3. **App not recognized** - Complete setup steps above
4. **Different environments** - Both devices must use same environment (Sandbox/Production)

**Solutions**:
- Use **Quick Match** instead of friend invites (faster for testing)
- Ensure both devices are signed into Game Center
- Check network connectivity
- Wait a few minutes and try again

---

## Testing Tips

### For Development (Sandbox)
- Use **test Apple IDs** (not your main account)
- Both devices need different Apple IDs
- Works immediately after setup (no App Store submission needed)
- Limited to 100 test users

### For Production
- Requires app to be in App Store or TestFlight
- Uses real Game Center accounts
- No user limit

### Quick Test Setup
1. **Device 1**: Sign in with Apple ID #1
2. **Device 2**: Sign in with Apple ID #2 (different account)
3. Both devices: Open app, tap "Connect" → "Quick Match"
4. Should auto-match within 30 seconds

---

## Common Issues

### "Game Center capability not found"
- Add it in Xcode: Signing & Capabilities → + Capability → Game Center

### "Bundle ID mismatch"
- Check both Xcode and App Store Connect
- Must be identical (case-sensitive)

### "Changes not taking effect"
- Wait 5-10 minutes after App Store Connect changes
- Close and reopen app
- Sign out and back into Game Center

### "Matchmaker won't show"
- Check that you're authenticated (see your name in logs)
- Ensure no other views are presenting
- Try Quick Match instead

---

## Still Having Issues?

1. **Check logs** for specific error messages
2. **Verify setup** using the checklist:
   - [ ] Game Center capability added in Xcode
   - [ ] App created in App Store Connect
   - [ ] Game Center enabled in App Store Connect
   - [ ] Bundle IDs match exactly
   - [ ] Signed into Game Center on device
   - [ ] Waited 5-10 minutes after setup

3. **Try Quick Match** first (simpler than friend invites)

4. **Check Apple Developer Forums** for similar issues

---

## Quick Checklist

Before testing multiplayer:
- [ ] Game Center capability added in Xcode
- [ ] App exists in App Store Connect
- [ ] Game Center enabled in App Store Connect
- [ ] Bundle ID matches in both places
- [ ] Signed into Game Center on device
- [ ] Waited 5-10 minutes after App Store Connect changes
- [ ] Two devices with different Apple IDs ready


