# Live Activity Image Troubleshooting Guide

## Problem
Egg images are not displaying in the Live Activity widget.

## Step-by-Step Troubleshooting

### Step 1: Verify Image Names Being Passed

The image names should be:
- `"egg"` for common eggs
- `"rareegg"` for rare eggs

**Check in TimerManager.swift (around line 108-113):**
```swift
// Map egg image name to actual asset name
let imageName = egg.title == "RareEgg" ? "rareegg" : "egg"
LiveActivityManager.shared.startLiveActivity(
    eggName: egg.title,
    eggImageName: imageName,  // Should be "egg" or "rareegg"
    duration: duration,
    startTime: Date()
)
```

### Step 2: Verify Asset Names in Xcode

1. Open Xcode
2. Navigate to `CrackedSwift/Assets.xcassets`
3. Find the image sets:
   - `egg.imageset` - should contain `egg.png`
   - `rareegg.imageset` - should contain `RareEgg.png`

4. **Check the asset names match exactly:**
   - The folder name: `egg.imageset` → image name: `"egg"`
   - The folder name: `rareegg.imageset` → image name: `"rareegg"`

### Step 3: Check Target Membership

**For Main App Assets:**
1. Select `CrackedSwift/Assets.xcassets/egg.imageset` in Xcode
2. Open the File Inspector (right panel, first tab)
3. Under "Target Membership", ensure:
   - ✅ `CrackedSwift` is checked
   - ✅ `CrackedSwiftWidgetExtension` is checked (THIS IS CRITICAL)

4. Repeat for `rareegg.imageset`

**Alternative: Copy Assets to Widget Extension**
If the above doesn't work, you can copy the images to the widget extension's asset catalog:
1. Navigate to `CrackedSwift/CrackedSwiftWidget/Assets.xcassets`
2. Right-click → "New Image Set"
3. Name it `egg`
4. Drag `egg.png` into the 1x slot
5. Repeat for `rareegg` with `RareEgg.png`

### Step 4: Add Debug Logging

Add this to `CrackedSwiftWidgetLiveActivity.swift` to see what's happening:

```swift
// In the lock screen view, replace the Image line with:
Group {
    let _ = print("🔍 [LiveActivity] Looking for image: '\(context.attributes.eggImageName)'")
    Image(context.attributes.eggImageName)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 50, height: 50)
        .onAppear {
            print("✅ [LiveActivity] Image view appeared for: '\(context.attributes.eggImageName)'")
        }
}
```

Check the Xcode console when the live activity appears.

### Step 5: Test Image Loading Directly

Add a test view to verify images can be loaded:

```swift
// Temporary test - add this somewhere to test
struct ImageTestView: View {
    var body: some View {
        VStack {
            Text("Testing Images")
            Image("egg")
                .resizable()
                .frame(width: 50, height: 50)
            Image("rareegg")
                .resizable()
                .frame(width: 50, height: 50)
        }
    }
}
```

### Step 6: Verify Bundle Access

Widget extensions run in a separate process and may need explicit bundle references.

**Option A: Use Main Bundle (if assets are shared)**
```swift
Image(context.attributes.eggImageName)
    .resizable()
    .aspectRatio(contentMode: .fit)
```

**Option B: Use Explicit Bundle (if needed)**
```swift
Group {
    if let uiImage = UIImage(named: context.attributes.eggImageName, 
                            in: Bundle(identifier: "com.yourbundle.CrackedSwift"), 
                            compatibleWith: nil) {
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
    } else {
        // Fallback
        Image(systemName: "oval.fill")
    }
}
```

### Step 7: Check Build Settings

1. Select your project in Xcode
2. Select the `CrackedSwiftWidgetExtension` target
3. Go to "Build Phases"
4. Expand "Copy Bundle Resources"
5. Verify `Assets.xcassets` is listed (or the individual image files)

### Step 8: Clean and Rebuild

1. **Clean Build Folder:** Product → Clean Build Folder (Shift+Cmd+K)
2. **Delete Derived Data:**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/CrackedSwift-*
   ```
3. **Rebuild:** Product → Build (Cmd+B)

### Step 9: Test on Device

Live Activities work differently on simulator vs device:
- **Simulator:** May have limitations with asset loading
- **Device:** More reliable for testing Live Activities

### Step 10: Verify Image File Exists

Check the actual files exist:
```bash
# From project root
ls -la "CrackedSwift/CrackedSwift/Assets.xcassets/egg.imageset/"
ls -la "CrackedSwift/CrackedSwift/Assets.xcassets/rareegg.imageset/"
```

Should show:
- `egg.imageset/egg.png`
- `rareegg.imageset/RareEgg.png`

## Quick Fix: Add Fallback with Debug Info

Update the live activity to show what's happening:

```swift
Group {
    Image(context.attributes.eggImageName)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 50, height: 50)
        .background(Color.red.opacity(0.3)) // Temporary: shows if view is rendering
        .overlay(
            Text(context.attributes.eggImageName)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(2)
                .background(Color.black.opacity(0.7))
        )
}
```

This will show:
- If the view is rendering (red background)
- What image name is being used (text overlay)

## Most Common Issues

1. **Target Membership:** Images not added to widget extension target
2. **Name Mismatch:** Asset name doesn't match what's passed (`"egg"` vs `"Egg"` vs `"common_egg"`)
3. **Missing Files:** Image files not actually in the imageset folder
4. **Bundle Access:** Widget extension can't access main app bundle assets

## Verification Checklist

- [ ] Image names in code match asset names exactly
- [ ] Assets are in both app and widget extension targets
- [ ] Image files exist in the imageset folders
- [ ] Clean build performed
- [ ] Tested on physical device (not just simulator)
- [ ] Console logs show correct image names being used




