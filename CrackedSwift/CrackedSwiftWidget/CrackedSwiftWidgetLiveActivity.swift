//
//  CrackedSwiftWidgetLiveActivity.swift
//  CrackedSwiftWidget
//
//  Created by Jacob Taylor on 23/11/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI
import UIKit

// App colors for widget (since DesignSystem might not be accessible)
extension Color {
    static let appBackgroundGreen = Color(red: 0.24, green: 0.48, blue: 0.37) // #3D7A5F
    static let appButtonGreen = Color(red: 0.43, green: 0.80, blue: 0.61) // #6ECB9B
}

struct CrackedSwiftWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            // Lock Screen/Banner UI
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Egg image with fallback (piggybank: banknote icon if asset missing)
                    Group {
                        if let uiImage = Self.loadEggUIImage(named: context.attributes.eggImageName) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                        } else if Self.isPiggybank(context.attributes.eggName) {
                            Image(systemName: "banknote.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.yellow)
                                .frame(width: 50, height: 50)
                        } else {
                            Image(systemName: "oval.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.appButtonGreen)
                                .frame(width: 50, height: 50)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if Self.isReadyState(context) {
                            Text(Self.readyTitle(context))
                                .font(.headline)
                                .foregroundColor(.white)
                        } else {
                            Text(Self.isPiggybank(context.attributes.eggName) ? context.attributes.eggName : "Hatching \(context.attributes.eggName)")
                                .font(.headline)
                                .foregroundColor(.white)
                            if context.state.isRunning {
                                Text(Self.isPiggybank(context.attributes.eggName) ? "Shaking..." : "Incubating...")
                                    .font(.subheadline)
                                    .foregroundColor(.appButtonGreen)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Timer display (or "Ready!" when at 0:00). Never use timerInterval with past endDate (crashes).
                    Group {
                        if Self.isReadyState(context) {
                            Text("Ready!")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                        } else if Self.canShowCountdown(context) {
                            Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        } else {
                            Text(Self.formatTime(context.state.timeRemaining))
                                .monospacedDigit()
                        }
                    }
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.appButtonGreen)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Progress bar
                ProgressView(value: Self.progress(for: context), total: 1.0)
                    .tint(.appButtonGreen)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .activityBackgroundTint(.appBackgroundGreen)
            .activitySystemActionForegroundColor(.white)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Group {
                            if let uiImage = Self.loadEggUIImage(named: context.attributes.eggImageName) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                            } else if Self.isPiggybank(context.attributes.eggName) {
                                Image(systemName: "banknote.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.yellow)
                                    .frame(width: 40, height: 40)
                            } else {
                                Image(systemName: "oval.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.appButtonGreen)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            if Self.isReadyState(context) {
                                Text(Self.readyTitle(context))
                                    .font(.caption)
                                    .bold()
                            } else {
                                Text(context.attributes.eggName)
                                    .font(.caption)
                                    .bold()
                                if context.state.isRunning {
                                    Text(Self.isPiggybank(context.attributes.eggName) ? "Shaking" : "Incubating")
                                        .font(.caption2)
                                        .foregroundColor(.appButtonGreen)
                                }
                            }
                        }
                    }
                    .padding(.leading)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Group {
                        if Self.isReadyState(context) {
                            Text("Ready!")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                        } else if Self.canShowCountdown(context) {
                            Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                        } else {
                            Text(Self.formatTime(context.state.timeRemaining))
                                .monospacedDigit()
                        }
                    }
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appButtonGreen)
                    .padding(.trailing)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ProgressView(value: Self.progress(for: context), total: 1.0)
                            .tint(.appButtonGreen)
                        
                        if Self.isReadyState(context) {
                            Text("Tap to open")
                                .font(.caption2)
                                .foregroundColor(.appButtonGreen)
                        } else if context.state.isRunning {
                            Text("Keep going!")
                                .font(.caption2)
                                .foregroundColor(.appButtonGreen)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
                
            } compactLeading: {
                // Compact leading: Show egg image
                Group {
                    if let uiImage = Self.loadEggUIImage(named: context.attributes.eggImageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                    } else if Self.isPiggybank(context.attributes.eggName) {
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.yellow)
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "oval.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.appButtonGreen)
                    }
                }
            } compactTrailing: {
                // Compact trailing: Show timer or "Ready!" (never timerInterval with past endDate)
                Group {
                    if Self.isReadyState(context) {
                        Text("Ready!")
                    } else if Self.canShowCountdown(context) {
                        Text(timerInterval: Date()...context.state.endDate, countsDown: true)
                    } else {
                        Text(Self.formatTime(context.state.timeRemaining))
                            .monospacedDigit()
                    }
                }
                .font(.caption)
                .foregroundColor(.appButtonGreen)
            } minimal: {
                // Minimal: Show egg image
                Group {
                    if let uiImage = Self.loadEggUIImage(named: context.attributes.eggImageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    } else if Self.isPiggybank(context.attributes.eggName) {
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "oval.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.appButtonGreen)
                    }
                }
            }
            .widgetURL(URL(string: "crackedswift://timer"))
            .keylineTint(.appButtonGreen)
        }
    }

    private static func progress(for context: ActivityViewContext<TimerAttributes>) -> Double {
        let remaining: TimeInterval
        if context.state.isRunning {
            remaining = max(0, context.state.endDate.timeIntervalSinceNow)
        } else {
            remaining = max(0, context.state.timeRemaining)
        }

        guard context.attributes.totalDuration > 0 else { return 0 }
        let p = 1.0 - (remaining / context.attributes.totalDuration)
        return min(1, max(0, p))
    }

    private static func formatTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// Widget extensions run in a separate bundle. Host app bundle is where
    /// egg/piggybank assets live; load from here so the widget can show them.
    private static func hostAppBundle() -> Bundle? {
        // Prefer bundle by identifier (reliable for app extensions)
        if let appBundle = Bundle(identifier: "Cracked.CrackedSwift") {
            return appBundle
        }
        // Fallback: derive from extension path .../CrackedSwift.app/PlugIns/...appex
        let extensionBundleURL = Bundle.main.bundleURL
        let appBundleURL = extensionBundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return Bundle(url: appBundleURL)
    }

    // MARK: - Memory-safe image loading (widgets have ~30MB limit)
    /// Max display size used in the widget; we decode at this size to avoid holding full-res bitmaps.
    private static let widgetImagePointSize: CGFloat = 50
    /// Single-entry cache: only one downscaled image in memory to prevent widget OOM.
    private static var cachedEggImage: (name: String, image: UIImage)?
    private static let cacheLock = NSLock()

    /// Load egg/piggybank image: try host app bundle first (assets live there),
    /// then extension bundle. Returns a small downscaled bitmap and caches at most one image.
    private static func loadEggUIImage(named name: String) -> UIImage? {
        let cacheKey = name
        cacheLock.lock()
        if let cached = cachedEggImage, cached.name == cacheKey {
            let img = cached.image
            cacheLock.unlock()
            return img
        }
        cacheLock.unlock()

        let candidates: [String]
        if name.lowercased() == "piggybank" {
            candidates = ["PiggyBank", "Piggybank"]
        } else {
            candidates = [name]
        }

        let bundles: [Bundle] = [hostAppBundle(), .main].compactMap { $0 }
        let downscaled: UIImage? = autoreleasepool {
            var fullRes: UIImage?
            for candidate in candidates {
                for bundle in bundles {
                    if let img = UIImage(named: candidate, in: bundle, compatibleWith: nil) {
                        fullRes = img
                        break
                    }
                }
                if fullRes != nil { break }
            }
            guard let source = fullRes else { return nil }
            return downscaleImage(source, maxPointSize: widgetImagePointSize) ?? source
        }

        guard let img = downscaled else { return nil }
        cacheLock.lock()
        cachedEggImage = (cacheKey, img)
        cacheLock.unlock()
        return img
    }

    /// Decode image at a small size to reduce widget memory (full-res decoding can be 1–10+ MB per image).
    private static func downscaleImage(_ image: UIImage, maxPointSize: CGFloat) -> UIImage? {
        let scale: CGFloat = 2 // Fixed scale in widget to avoid UIScreen dependency; 50pt → 100px is enough.
        let maxPixels = Int(maxPointSize * scale)
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let ratio = min(CGFloat(maxPixels) / size.width, CGFloat(maxPixels) / size.height)
        if ratio >= 1 { return image }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized
    }

    /// Whether the current egg is Piggybank (for fallback icon).
    private static func isPiggybank(_ eggName: String) -> Bool {
        eggName.lowercased() == "piggybank"
    }

    /// When timer has reached 0:00, show "ready to hatch" or "ready to empty" instead of countdown.
    private static func isReadyState(_ context: ActivityViewContext<TimerAttributes>) -> Bool {
        context.state.timeRemaining <= 0 && !context.state.isRunning
    }

    /// Safe to use Text(timerInterval:) only when endDate is in the future; past endDate can crash the widget.
    private static func canShowCountdown(_ context: ActivityViewContext<TimerAttributes>) -> Bool {
        context.state.isRunning && context.state.endDate.timeIntervalSinceNow > 0
    }

    private static func readyTitle(_ context: ActivityViewContext<TimerAttributes>) -> String {
        if Self.isPiggybank(context.attributes.eggName) {
            return "Piggybank is ready to empty"
        }
        return "Egg is ready to hatch"
    }
}
