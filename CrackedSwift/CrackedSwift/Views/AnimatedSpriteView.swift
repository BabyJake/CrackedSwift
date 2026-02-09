//
//  AnimatedSpriteView.swift
//  CrackedSwift
//
//  Handles sprite sheet animations for animals
//

import SwiftUI
import Combine

// MARK: - Pre-loaded frame cache (avoids UIImage(named:) on every tick)

/// Shared cache that holds pre-loaded animation frames for each animal.
/// Images are loaded once on first access and reused across all instances.
final class AnimationFrameCache {
    static let shared = AnimationFrameCache()

    private var cache: [String: [UIImage]] = [:]
    private let lock = NSLock()

    private init() {}

    /// Returns cached frames for the given key, or loads them if not cached yet.
    func frames(for key: String, loader: () -> [UIImage]) -> [UIImage] {
        lock.lock()
        if let existing = cache[key] {
            lock.unlock()
            return existing
        }
        lock.unlock()

        let loaded = loader()

        lock.lock()
        cache[key] = loaded
        lock.unlock()
        return loaded
    }

    /// Remove all cached frames (e.g. on memory warning).
    func purge() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}

// MARK: - Animation Timer

/// Timer that drives frame animation. Publishes only the frame index.
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

    deinit {
        timer?.invalidate()
    }
}

// MARK: - AnimatedSpriteView

struct AnimatedSpriteView: View {
    let baseName: String
    let animationName: String
    let frameCount: Int
    let frameDuration: Double
    let startFrame: Int
    let frameFormat: FrameFormat

    @StateObject private var timerManager: AnimationTimer

    /// Pre-loaded frames for this animal (populated in onAppear).
    @State private var frames: [UIImage] = []

    enum FrameFormat {
        case underscoreWithAnimation  // Cat_Idle_1
        case underscoreSimple         // Cat_1
        case paddedNumber             // cat0001, Cat0001
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

    var body: some View {
        imageView
            .clipped()
            .background(Color.clear)
            .onAppear {
                loadFrames()
                startAnimation()
            }
            .onDisappear {
                timerManager.stop()
            }
    }

    // MARK: - Image rendering (no UIImage(named:) calls here — uses pre-loaded array)

    @ViewBuilder
    private var imageView: some View {
        let frameIndex = timerManager.currentFrame - startFrame
        if !frames.isEmpty, frameIndex >= 0, frameIndex < frames.count {
            Image(uiImage: frames[frameIndex])
                .resizable()
                .scaledToFit()
        } else if let fallback = UIImage(named: baseName) {
            // Static fallback while frames load or if no animation
            Image(uiImage: fallback)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Frame loading

    private func loadFrames() {
        let cacheKey = "\(baseName)_\(animationName)_\(frameFormat)"
        frames = AnimationFrameCache.shared.frames(for: cacheKey) {
            var loaded: [UIImage] = []
            for i in startFrame ..< (startFrame + frameCount) {
                if let img = loadSingleFrame(i) {
                    loaded.append(img)
                }
            }
            return loaded
        }
    }

    private func loadSingleFrame(_ frame: Int) -> UIImage? {
        let names = imageNameCandidates(for: frame)
        for name in names {
            if let img = UIImage(named: name) {
                return img
            }
        }
        return nil
    }

    /// Returns candidate image names to try for a given frame number (most likely first).
    private func imageNameCandidates(for frame: Int) -> [String] {
        switch frameFormat {
        case .underscoreWithAnimation:
            return ["\(baseName)_\(animationName)_\(frame)"]
        case .underscoreSimple:
            return ["\(baseName)_\(frame)"]
        case .paddedNumber:
            let padded = String(format: "%04d", frame)
            return [
                "\(baseName.lowercased())\(padded)",
                "\(baseName.capitalized)\(padded)"
            ]
        }
    }

    private func startAnimation() {
        guard frameCount > 1 else { return }
        timerManager.start()
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

    // MARK: - Result cache (detection is expensive — only do it once per animal)

    private static var configCache: [String: AnimalAnimationConfig?] = [:]
    private static let cacheLock = NSLock()

    /// Checks if an animal has animation frames available
    static func hasAnimationFrames(for animalName: String, animationName: String = "Idle") -> Bool {
        return UIImage(named: "\(animalName)_\(animationName)_1") != nil ||
               UIImage(named: "\(animalName)_1") != nil ||
               UIImage(named: "\(animalName.lowercased())0001") != nil ||
               UIImage(named: "\(animalName.capitalized)0001") != nil
    }

    /// Detects which frame format is being used
    static func detectFrameFormat(for animalName: String, animationName: String = "Idle") -> AnimatedSpriteView.FrameFormat {
        if UIImage(named: "\(animalName)_\(animationName)_1") != nil {
            return .underscoreWithAnimation
        }
        if UIImage(named: "\(animalName)_1") != nil {
            return .underscoreSimple
        }
        if UIImage(named: "\(animalName.lowercased())0001") != nil ||
           UIImage(named: "\(animalName.capitalized)0001") != nil {
            return .paddedNumber
        }
        return .underscoreWithAnimation
    }

    /// Counts how many animation frames are available
    static func countFrames(for animalName: String, animationName: String = "Idle") -> Int {
        var count = 0
        var frameNumber = 1

        // Try format: AnimalName_AnimationName_FrameNumber
        while UIImage(named: "\(animalName)_\(animationName)_\(frameNumber)") != nil {
            count += 1
            frameNumber += 1
        }
        if count > 0 { return count }

        // Try format: AnimalName_FrameNumber
        frameNumber = 1
        while UIImage(named: "\(animalName)_\(frameNumber)") != nil {
            count += 1
            frameNumber += 1
        }
        if count > 0 { return count }

        // Try format: animalname0001
        frameNumber = 1
        let lowercaseName = animalName.lowercased()
        while UIImage(named: String(format: "%@%04d", lowercaseName, frameNumber)) != nil {
            count += 1
            frameNumber += 1
        }
        if count > 0 { return count }

        // Try capitalized: Cat0001
        let capitalizedName = animalName.capitalized
        frameNumber = 1
        while UIImage(named: String(format: "%@%04d", capitalizedName, frameNumber)) != nil {
            count += 1
            frameNumber += 1
        }
        return count
    }

    /// Gets animation config for an animal (cached — safe to call from view body).
    static func getAnimationConfig(for animalName: String, animationName: String = "Idle") -> AnimalAnimationConfig? {
        let key = "\(animalName)_\(animationName)"

        cacheLock.lock()
        if let cached = configCache[key] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        // Compute (only happens once per animal)
        let frameCount = countFrames(for: animalName, animationName: animationName)
        let result: AnimalAnimationConfig?
        if frameCount > 1 {
            let format = detectFrameFormat(for: animalName, animationName: animationName)
            result = AnimalAnimationConfig(
                animationName: animationName,
                frameCount: frameCount,
                frameDuration: 0.15,
                startFrame: 1,
                frameFormat: format
            )
        } else {
            result = nil
        }

        cacheLock.lock()
        configCache[key] = result
        cacheLock.unlock()
        return result
    }
}
