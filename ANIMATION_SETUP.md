# How to Add Animation PNGs to Your Project

This guide explains how to add your animation PNG files to the project so animals can animate in the sanctuary.

## Quick Steps

1. **Organize your PNG files** with consistent naming
2. **Add them to Assets.xcassets** in Xcode
3. **The animation system will automatically detect and use them**

---

## Naming Convention

Your PNG files should follow one of these naming patterns:

### Option 1: Padded Number Format (Recommended for Unity exports)
```
{animalname}{4-digit-frame-number}.png
```

**Examples:**
- `cat0001.png`
- `cat0002.png`
- `cat0003.png`
- `cat0004.png`
- `Cat0001.png` (capitalized also works)
- `Cat0002.png`
- etc.

**Note:** The system automatically detects this format and uses 4-digit padding with leading zeros.

### Option 2: With Animation Name
```
{AnimalName}_{AnimationName}_{FrameNumber}.png
```

**Examples:**
- `Cat_Idle_1.png`
- `Cat_Idle_2.png`
- `Cat_Idle_3.png`
- `Cat_Idle_4.png`
- `Cat_Walk_1.png`
- `Cat_Walk_2.png`
- etc.

### Option 3: Simple Format
```
{AnimalName}_{FrameNumber}.png
```

**Examples:**
- `Cat_1.png`
- `Cat_2.png`
- `Cat_3.png`
- `Cat_4.png`

---

## Step-by-Step: Adding PNGs to Xcode

### Method 1: Individual Image Sets (Recommended for Animations)

1. **Open Xcode** and navigate to `Assets.xcassets` in the Project Navigator

2. **For each animation frame**, create a new Image Set:
   - Right-click in `Assets.xcassets` → **"New Image Set"**
   - Name it exactly as your PNG filename (without `.png`)
     - Example: `Cat_Idle_1`, `Cat_Idle_2`, etc.

3. **Drag your PNG file** into the Image Set:
   - Drag the PNG into the "Universal" slot (or specific @1x, @2x, @3x slots)
   - Xcode will automatically use it for all scales

4. **Repeat for all frames** of your animation

### Method 2: Batch Import (Faster)

1. **Select all your PNG files** in Finder
2. **Drag them directly into `Assets.xcassets`** in Xcode
3. Xcode will automatically create Image Sets for each file
4. **Verify the names** match your naming convention

---

## Example: Adding a Cat Animation (cat0001 format)

If you have animation frames named like `cat0001.png`, `cat0002.png`, etc.:

1. **PNG Files:**
   - `cat0001.png`
   - `cat0002.png`
   - `cat0003.png`
   - `cat0004.png`
   - (and so on...)

2. **In Assets.xcassets**, create Image Sets with the exact same names:
   - `cat0001` → drag `cat0001.png`
   - `cat0002` → drag `cat0002.png`
   - `cat0003` → drag `cat0003.png`
   - `cat0004` → drag `cat0004.png`
   - (repeat for all frames)

3. **That's it!** The animation system will automatically:
   - Detect the frames (looks for `cat0001`, `cat0002`, etc.)
   - Count how many frames exist
   - Play the animation in a loop

**Note:** The system supports both lowercase (`cat0001`) and capitalized (`Cat0001`) versions. Make sure your Image Set names in Assets.xcassets match your file names exactly!

---

## Animation Settings

The animation system uses these defaults:
- **Frame Duration**: 0.15 seconds (150ms) per frame
- **Animation Name**: "Idle" (for default animations)
- **Start Frame**: 1

### Customizing Animation Speed

If you want to change the animation speed, you can modify the `AnimatedSpriteView` in `SanctuaryView.swift`:

```swift
AnimatedSpriteView(
    baseName: instance.animalName,
    animationName: "Idle",
    frameCount: config.frameCount,
    frameDuration: 0.1,  // Faster: 100ms per frame
    startFrame: 1
)
```

---

## Multiple Animations

If you have multiple animations for the same animal (e.g., Idle, Walk, Run):

1. **Name them with the animation type:**
   - `Cat_Idle_1.png`, `Cat_Idle_2.png`, etc.
   - `Cat_Walk_1.png`, `Cat_Walk_2.png`, etc.

2. **The system currently uses "Idle" by default**, but you can extend it to support multiple animations per animal.

---

## Troubleshooting

### Animation Not Playing?

1. **Check naming**: Make sure your Image Set names match exactly:
   - ✅ `Cat_Idle_1` (correct)
   - ❌ `cat_idle_1` (wrong - case sensitive)
   - ❌ `Cat_Idle_01` (wrong - no leading zero)

2. **Check frame numbers**: Start from 1, not 0:
   - ✅ `Cat_Idle_1`, `Cat_Idle_2`, `Cat_Idle_3`
   - ❌ `Cat_Idle_0`, `Cat_Idle_1`, `Cat_Idle_2`

3. **Verify in Assets.xcassets**: Open the Image Set and make sure the PNG is actually there

4. **Check console**: The system will fall back to static images if frames aren't found

### Only First Frame Shows?

- Make sure you have **multiple frames** (at least 2)
- Check that frame numbers are **consecutive** (1, 2, 3, 4... not 1, 3, 5)

### Animation Too Fast/Slow?

- Adjust `frameDuration` in the `AnimatedSpriteView` initialization
- Lower value = faster animation
- Higher value = slower animation

---

## Tips

- **Frame Count**: The system automatically counts frames, so you don't need to specify how many you have
- **Consistent Naming**: Use the same naming pattern for all animals
- **File Size**: Keep PNG files optimized - large files can slow down the app
- **Frame Rate**: 0.15 seconds (150ms) per frame = ~6.67 FPS, which is good for idle animations

---

## Current Limitations

- Currently supports one animation per animal (defaults to "Idle")
- All animals use the same frame duration (customizable per animal coming soon)
- Animation loops continuously (no stop/start controls yet)

---

## Next Steps

Once your PNGs are added:
1. Build and run the app
2. Visit the Sanctuary
3. Your animals should automatically animate!

If you want to add support for multiple animations (Walk, Run, etc.) or per-animal animation speeds, let me know!

