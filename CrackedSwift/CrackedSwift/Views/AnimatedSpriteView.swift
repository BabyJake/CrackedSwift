//
//  AnimatedSpriteView.swift
//  CrackedSwift
//
//  Handles sprite sheet animations for animals
//

import SwiftUI
import Combine

// Timer manager class to handle animation updates
class AnimationTimer: ObservableObject {
    @Published var currentFrame: Int
    private var timer: Timer?
    private let frameCount: Int
    private let startFrame: Int
    private let frameDuration: Double
    
    init(frameCount: Int, startFrame: Int, frameDuration: Double) {
        self.frameCount = frameCount
        self.startFrame = startFrame
        self.frameDuration = frameDuration
        self.currentFrame = startFrame
    }
    
    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.currentFrame = ((self.currentFrame - self.startFrame + 1) % self.frameCount) + self.startFrame
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

struct AnimatedSpriteView: View {
    let baseName: String  // e.g., "Cat"
    let animationName: String  // e.g., "Idle", "Walk" (optional)
    let frameCount: Int
    let frameDuration: Double
    let startFrame: Int
    let frameFormat: FrameFormat  // Format of frame naming
    
    @StateObject private var timerManager: AnimationTimer
    
    enum FrameFormat {
        case underscoreWithAnimation  // Cat_Idle_1
        case underscoreSimple         // Cat_1
        case paddedNumber              // cat0001, Cat0001
    }
    
    init(
        baseName: String,
        animationName: String = "Idle",
        frameCount: Int,
        frameDuration: Double = 0.15,
        startFrame: Int = 1,
        frameFormat: FrameFormat = .underscoreWithAnimation
    ) {
        self.baseName = baseName
        self.animationName = animationName
        self.frameCount = frameCount
        self.frameDuration = frameDuration
        self.startFrame = startFrame
        self.frameFormat = frameFormat
        _timerManager = StateObject(wrappedValue: AnimationTimer(frameCount: frameCount, startFrame: startFrame, frameDuration: frameDuration))
    }
    
    private func getImageName(for frame: Int) -> String {
        switch frameFormat {
        case .underscoreWithAnimation:
            return "\(baseName)_\(animationName)_\(frame)"
        case .underscoreSimple:
            return "\(baseName)_\(frame)"
        case .paddedNumber:
            // Format: cat0001, cat0002, etc. (4 digits with leading zeros)
            let paddedFrame = String(format: "%04d", frame)
            // Try lowercase first, then capitalized
            let lowercaseName = baseName.lowercased()
            let capitalizedName = baseName.capitalized
            return "\(lowercaseName)\(paddedFrame)" // Primary: cat0001
        }
    }
    
    var body: some View {
        imageView
            .clipped()
            .background(Color.clear)
            .onAppear {
                print("🎬 [AnimatedSpriteView] Animation appearing - baseName: '\(baseName)', frameCount: \(frameCount), format: \(frameFormat), startFrame: \(startFrame)")
                startAnimation()
            }
            .onDisappear {
                stopAnimation()
            }
    }
    
    @ViewBuilder
    private var imageView: some View {
        let imageName = getImageName(for: timerManager.currentFrame)
        
        // DEBUG: Print what we're looking for
        let _ = print("🔍 [AnimatedSpriteView] Looking for image: '\(imageName)', currentFrame: \(timerManager.currentFrame), frameCount: \(frameCount), format: \(frameFormat)")
        
        // Try the detected format
        if let image = UIImage(named: imageName) {
            let _ = print("✅ [AnimatedSpriteView] Found image: '\(imageName)'")
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
        // For padded format, also try capitalized version
        else if frameFormat == .paddedNumber {
            paddedNumberImageView(imageName: imageName)
        }
        // Fallback: Try just base name (static image)
        else if let image = UIImage(named: baseName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
        // Final fallback
        else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    @ViewBuilder
    private func paddedNumberImageView(imageName: String) -> some View {
        let capitalizedName = baseName.capitalized
        let paddedFrame = String(format: "%04d", timerManager.currentFrame)
        let capitalizedImageName = "\(capitalizedName)\(paddedFrame)"
        let _ = print("🔄 [AnimatedSpriteView] Trying capitalized: '\(capitalizedImageName)'")
        
        if let image = UIImage(named: capitalizedImageName) {
            let _ = print("✅ [AnimatedSpriteView] Found capitalized image: '\(capitalizedImageName)'")
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else if let image = UIImage(named: baseName) {
            let _ = print("⚠️ [AnimatedSpriteView] Using fallback base name: '\(baseName)'")
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            let _ = print("❌ [AnimatedSpriteView] No image found, using placeholder")
            Image(systemName: "pawprint.fill")
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0))
        }
    }
    
    private func startAnimation() {
        // Only animate if we have multiple frames
        guard frameCount > 1 else {
            print("⚠️ [AnimatedSpriteView] Not starting animation - only \(frameCount) frames (need > 1)")
            return
        }
        
        print("▶️ [AnimatedSpriteView] Starting animation with \(frameCount) frames, duration: \(frameDuration)s per frame")
        timerManager.start()
    }
    
    private func stopAnimation() {
        timerManager.stop()
    }
}

// MARK: - Animation Configuration Helper

struct AnimalAnimationConfig {
    let animationName: String
    let frameCount: Int
    let frameDuration: Double
    let startFrame: Int
    let frameFormat: AnimatedSpriteView.FrameFormat
    
    static let defaultIdle = AnimalAnimationConfig(
        animationName: "Idle",
        frameCount: 4,
        frameDuration: 0.15,
        startFrame: 1,
        frameFormat: .underscoreWithAnimation
    )
}

// MARK: - Helper to detect animation frames

struct AnimationFrameDetector {
    /// Checks if an animal has animation frames available
    static func hasAnimationFrames(for animalName: String, animationName: String = "Idle") -> Bool {
        // Check if first frame exists in any format
        return UIImage(named: "\(animalName)_\(animationName)_1") != nil ||
               UIImage(named: "\(animalName)_1") != nil ||
               UIImage(named: "\(animalName.lowercased())0001") != nil ||
               UIImage(named: "\(animalName.capitalized)0001") != nil
    }
    
    /// Detects which frame format is being used
    static func detectFrameFormat(for animalName: String, animationName: String = "Idle") -> AnimatedSpriteView.FrameFormat {
        print("🔍 [FrameDetector] Detecting format for: '\(animalName)'")
        
        // Check format: AnimalName_AnimationName_FrameNumber (e.g., "Cat_Idle_1")
        let format1 = "\(animalName)_\(animationName)_1"
        if UIImage(named: format1) != nil {
            print("  ✅ Detected format: underscoreWithAnimation ('\(format1)')")
            return .underscoreWithAnimation
        }
        
        // Check format: AnimalName_FrameNumber (e.g., "Cat_1")
        let format2 = "\(animalName)_1"
        if UIImage(named: format2) != nil {
            print("  ✅ Detected format: underscoreSimple ('\(format2)')")
            return .underscoreSimple
        }
        
        // Check format: animalname0001 (e.g., "cat0001")
        let lowercaseFormat = "\(animalName.lowercased())0001"
        let capitalizedFormat = "\(animalName.capitalized)0001"
        let lowercaseExists = UIImage(named: lowercaseFormat) != nil
        let capitalizedExists = UIImage(named: capitalizedFormat) != nil
        
        print("  🔍 Checking lowercase: '\(lowercaseFormat)' → \(lowercaseExists)")
        print("  🔍 Checking capitalized: '\(capitalizedFormat)' → \(capitalizedExists)")
        
        if lowercaseExists || capitalizedExists {
            print("  ✅ Detected format: paddedNumber")
            return .paddedNumber
        }
        
        // Default
        print("  ⚠️ No format detected, using default: underscoreWithAnimation")
        return .underscoreWithAnimation
    }
    
    /// Counts how many animation frames are available
    static func countFrames(for animalName: String, animationName: String = "Idle") -> Int {
        var count = 0
        var frameNumber = 1
        
        print("🔢 [FrameDetector] Counting frames for: '\(animalName)'")
        
        // Try format: AnimalName_AnimationName_FrameNumber
        while UIImage(named: "\(animalName)_\(animationName)_\(frameNumber)") != nil {
            count += 1
            frameNumber += 1
        }
        if count > 0 {
            print("  ✅ Found \(count) frames in format: '\(animalName)_\(animationName)_X'")
            return count
        }
        
        // If no frames found, try format: AnimalName_FrameNumber
        frameNumber = 1
        while UIImage(named: "\(animalName)_\(frameNumber)") != nil {
            count += 1
            frameNumber += 1
        }
        if count > 0 {
            print("  ✅ Found \(count) frames in format: '\(animalName)_X'")
            return count
        }
        
        // If still no frames, try format: animalname0001, animalname0002, etc.
        frameNumber = 1
        let lowercaseName = animalName.lowercased()
        let capitalizedName = animalName.capitalized
        
        print("  🔍 Trying lowercase format: '\(lowercaseName)XXXX'")
        // Try lowercase first (cat0001)
        while UIImage(named: String(format: "%@%04d", lowercaseName, frameNumber)) != nil {
            count += 1
            frameNumber += 1
        }
        
        if count > 0 {
            print("  ✅ Found \(count) frames in lowercase format: '\(lowercaseName)XXXX'")
            return count
        }
        
        // If no lowercase, try capitalized (Cat0001)
        print("  🔍 Trying capitalized format: '\(capitalizedName)XXXX'")
        frameNumber = 1
        while UIImage(named: String(format: "%@%04d", capitalizedName, frameNumber)) != nil {
            count += 1
            frameNumber += 1
        }
        
        if count > 0 {
            print("  ✅ Found \(count) frames in capitalized format: '\(capitalizedName)XXXX'")
        } else {
            print("  ❌ No frames found in any format")
        }
        
        return count
    }
    
    /// Gets animation config for an animal
    static func getAnimationConfig(for animalName: String, animationName: String = "Idle") -> AnimalAnimationConfig? {
        print("🎯 [FrameDetector] Getting animation config for: '\(animalName)'")
        
        // Check what formats exist
        let lowercaseCheck = UIImage(named: "\(animalName.lowercased())0001")
        let capitalizedCheck = UIImage(named: "\(animalName.capitalized)0001")
        print("  🧪 Test - lowercase '\(animalName.lowercased())0001' found: \(lowercaseCheck != nil)")
        print("  🧪 Test - capitalized '\(animalName.capitalized)0001' found: \(capitalizedCheck != nil)")
        
        let frameCount = countFrames(for: animalName, animationName: animationName)
        print("  📊 Frame count detected: \(frameCount)")
        
        guard frameCount > 1 else {
            print("  ❌ [FrameDetector] Not enough frames (\(frameCount)), returning nil")
            return nil
        }
        
        let format = detectFrameFormat(for: animalName, animationName: animationName)
        print("  ✅ [FrameDetector] Format detected: \(format)")
        
        let config = AnimalAnimationConfig(
            animationName: animationName,
            frameCount: frameCount,
            frameDuration: 0.15, // Default 150ms per frame
            startFrame: 1,
            frameFormat: format
        )
        
        print("  ✅ [FrameDetector] Returning config with \(frameCount) frames")
        return config
    }
}

