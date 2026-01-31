# Quick Fix Checklist for Live Activity Images

## Immediate Steps to Check (5 minutes)

### 1. Verify Image Names Match (30 seconds)
- Open `TimerManager.swift` line 109
- Confirm it says: `let imageName = egg.title == "RareEgg" ? "rareegg" : "egg"`
- The values must be exactly: `"egg"` and `"rareegg"` (lowercase, no spaces)

### 2. Check Asset Target Membership (2 minutes)
**In Xcode:**
1. Click on `CrackedSwift/Assets.xcassets/egg.imageset` in the Project Navigator
2. Open File Inspector (right panel, first icon)
3. Under "Target Membership", check:
   - ✅ `CrackedSwift` 
   - ✅ `CrackedSwiftWidgetExtension` ← **MUST BE CHECKED**

4. Repeat for `rareegg.imageset`

**If widget extension is NOT checked:**
- Check the box for `CrackedSwiftWidgetExtension`
- Clean build (Shift+Cmd+K)
- Rebuild (Cmd+B)

### 3. Verify Asset Folder Names (1 minute)
**In Finder or Xcode:**
- `egg.imageset` folder exists → image name is `"egg"`
- `rareegg.imageset` folder exists → image name is `"rareegg"`

**The folder name (without .imageset) must match the string passed to Image()**

### 4. Test with Debug Overlay (1 minute)
The code now shows a text overlay if the image fails to load. When you see the live activity:
- If you see the egg image → ✅ Working!
- If you see an oval with text → The text shows what image name it's looking for
  - Check if the text matches your asset names exactly

### 5. Clean Build (30 seconds)
1. Product → Clean Build Folder (Shift+Cmd+K)
2. Product → Build (Cmd+B)
3. Run on device (Live Activities work better on real devices)

## What the Debug Code Does

The updated code now:
1. Tries to load the image using `UIImage(named:)`
2. If that fails, shows a green oval placeholder
3. On the lock screen view, also shows the image name as text (for debugging)

## Expected Behavior

**When working correctly:**
- Lock screen: Shows actual egg image (50x50)
- Dynamic Island expanded: Shows egg image (40x40)
- Dynamic Island compact: Shows egg image (22x22)
- Dynamic Island minimal: Shows egg image (20x20)

**When NOT working:**
- You'll see green oval placeholders
- Lock screen will show text overlay with the image name being searched

## Most Likely Fix

**90% of the time, it's Step 2:**
The widget extension target doesn't have access to the assets. Check the Target Membership!

## If Still Not Working

See `LIVE_ACTIVITY_IMAGE_TROUBLESHOOTING.md` for detailed troubleshooting steps.




