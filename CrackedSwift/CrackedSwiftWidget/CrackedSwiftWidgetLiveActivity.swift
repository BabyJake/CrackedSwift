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
                    // Egg image with fallback
                    Group {
                        // Try loading from main bundle first
                        if let uiImage = Self.loadEggUIImage(named: context.attributes.eggImageName) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50, height: 50)
                        } else {
                            // Fallback: try system image or placeholder
                            Image(systemName: "oval.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.appButtonGreen)
                                .overlay(
                                    // Debug: show what image name we're looking for
                                    Text(context.attributes.eggImageName)
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(2)
                                        .background(Color.black.opacity(0.7))
                                        .cornerRadius(4)
                                )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hatching \(context.attributes.eggName)")
                            .font(.headline)
                            .foregroundColor(.white)
                        if context.state.isRunning {
                            Text("Incubating...")
                                .font(.subheadline)
                                .foregroundColor(.appButtonGreen)
                        }
                    }
                    
                    Spacer()
                    
                    // Timer display
                    Group {
                        if context.state.isRunning {
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
                            } else {
                                Image(systemName: "oval.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.appButtonGreen)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.eggName)
                                .font(.caption)
                                .bold()
                            if context.state.isRunning {
                                Text("Incubating")
                                    .font(.caption2)
                                    .foregroundColor(.appButtonGreen)
                            }
                        }
                    }
                    .padding(.leading)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Group {
                        if context.state.isRunning {
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
                        
                        if context.state.isRunning {
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
                    } else {
                        Image(systemName: "oval.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.appButtonGreen)
                    }
                }
            } compactTrailing: {
                // Compact trailing: Show timer
                Group {
                    if context.state.isRunning {
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

    /// Widget extensions run in a separate bundle. This locates the containing
    /// app bundle so we can load shared assets (egg images) from the main app.
    private static func hostAppBundle() -> Bundle? {
        // .../CrackedSwift.app/PlugIns/CrackedSwiftWidgetExtension.appex
        let extensionBundleURL = Bundle.main.bundleURL
        let appBundleURL = extensionBundleURL
            .deletingLastPathComponent() // PlugIns
            .deletingLastPathComponent() // CrackedSwift.app
        return Bundle(url: appBundleURL)
    }

    private static func loadEggUIImage(named name: String) -> UIImage? {
        // Piggybank asset is named "PiggyBank" — use it whenever the egg is piggybank.
        var candidates: [String] = []
        if name.lowercased() == "piggybank" {
            candidates = ["PiggyBank"]
            if name != "PiggyBank" { candidates.append(name) }
        } else {
            candidates = [name]
        }

        // Try host app bundle first, then extension bundle.
        let bundles: [Bundle] = [hostAppBundle(), .main].compactMap { $0 }

        for candidate in candidates {
            for bundle in bundles {
                if let img = UIImage(named: candidate, in: bundle, compatibleWith: nil) {
                    return img
                }
            }
        }

        return nil
    }
}
