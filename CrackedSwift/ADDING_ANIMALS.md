# How to Add Animals and Images

This guide explains how to easily add new animals to your game.

## Quick Steps

1. **Add the animal to `AnimalDatabase.swift`**
2. **Add the animal image to `Assets.xcassets`**
3. **Add the animal to an egg's spawn chances in `Egg.swift`** (optional)

---

## Step 1: Add Animal to Database

Open `CrackedSwift/Models/AnimalDatabase.swift` and add your animal to the `animals` dictionary:

```swift
"YourAnimalName": AnimalData(
    name: "YourAnimalName",
    imageName: "youranimalname",  // Must match Image Set name in Assets.xcassets
    rarity: .common,              // .common, .rare, .epic, or .legendary
    description: "A description of your animal"
),
```

### Example:
```swift
"Penguin": AnimalData(
    name: "Penguin",
    imageName: "penguin",
    rarity: .rare,
    description: "A cute penguin"
),
```

---

## Step 2: Add Image to Assets

1. **Export your animal sprite** from Unity (PNG format recommended)
2. **Open Xcode** and navigate to `Assets.xcassets`
3. **Create a new Image Set**:
   - Right-click in `Assets.xcassets` → "New Image Set"
   - Name it exactly as your `imageName` (e.g., `penguin`)
4. **Drag your sprite files** into the Image Set:
   - For @1x, @2x, @3x: drag the appropriate resolution images
   - Or just drag one image and Xcode will use it for all scales

**Important:** The Image Set name must match the `imageName` in `AnimalDatabase.swift`!

---

## Step 3: Add Animal to Egg (Optional)

If you want this animal to hatch from a specific egg, open `CrackedSwift/Models/Egg.swift` and add it to an egg's `spawnChances`:

```swift
Egg(
    title: "RareEgg",
    description: "A rare egg",
    baseCost: 500,
    imageName: "rare_egg",
    spawnChances: [
        AnimalSpawnChance(animalName: "Penguin", spawnChance: 30.0),
        // ... other animals
    ]
)
```

**Note:** The `animalName` must exactly match the name in `AnimalDatabase.swift`!

---

## Tips

- **Image naming**: Use lowercase, no spaces (e.g., `penguin`, `red_fox`)
- **Spawn chances**: Total doesn't need to equal 100 - the system normalizes automatically
- **Rarity**: Use `.common`, `.rare`, `.epic`, or `.legendary` for organization
- **Testing**: Use 0:00 timer to quickly test hatching

---

## Example: Adding "Lion"

1. **In `AnimalDatabase.swift`:**
```swift
"Lion": AnimalData(
    name: "Lion",
    imageName: "lion",
    rarity: .epic,
    description: "The king of the jungle"
),
```

2. **In `Assets.xcassets`:**
   - Create Image Set named `lion`
   - Add lion sprite images

3. **In `Egg.swift` (if you want Lion to hatch from RareEgg):**
```swift
AnimalSpawnChance(animalName: "Lion", spawnChance: 10.0),
```

That's it! The Lion will now appear in the sanctuary when hatched.


