//
//  TutorialOverlayView.swift
//  CrackedSwift
//
//  Full-screen overlay that displays step-by-step tutorial coach marks.
//  Only handles the "card" steps (welcome, sanctuary, shop).
//  Interactive steps (tapNest, egg selection) are handled by the
//  respective views themselves.
//

import SwiftUI

struct TutorialOverlayView: View {
    @ObservedObject var tutorial = TutorialManager.shared
    
    /// Steps this overlay actually renders.
    private var shouldShow: Bool {
        tutorial.isActive && overlaySteps.contains(tutorial.currentStep)
    }
    
    private let overlaySteps: Set<TutorialManager.TutorialStep> = [
        .welcome, .showSanctuary, .showShop
    ]
    
    var body: some View {
        if shouldShow {
            ZStack {
                // Semi-transparent backdrop
                Color.black.opacity(tutorial.currentStep == .welcome ? 0.7 : 0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Only advance on welcome tap
                        if tutorial.currentStep == .welcome {
                            tutorial.next()
                        }
                    }
                
                // Content
                switch tutorial.currentStep {
                case .welcome:
                    welcomeCard
                        .transition(.scale.combined(with: .opacity))
                case .showSanctuary:
                    sanctuaryTooltip
                        .transition(.move(edge: .top).combined(with: .opacity))
                case .showShop:
                    shopTooltip
                        .transition(.move(edge: .top).combined(with: .opacity))
                default:
                    EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.35), value: tutorial.currentStep)
        }
    }
    
    // MARK: - Welcome Card
    
    private var welcomeCard: some View {
        VStack(spacing: 16) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("🥚")
                    .font(.system(size: 56))
                
                Text("Welcome to Fauna!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Study to hatch animals and build your sanctuary.\nLet's show you around!")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Button(action: { tutorial.next() }) {
                    Text("Let's Go!")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.backgroundGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.white))
                }
                .padding(.top, 4)
                
                skipButton
            }
            .padding(28)
            .background(cardBackground)
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Sanctuary Tooltip
    
    private var sanctuaryTooltip: some View {
        VStack {
            tooltipBubble(
                icon: "🌿",
                title: "Your Sanctuary",
                body: "All your hatched animals appear here! Drag them around to arrange your collection.",
                buttonText: "Next",
                action: { tutorial.next() }
            )
            .padding(.top, 80)
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Shop Tooltip
    
    private var shopTooltip: some View {
        VStack {
            tooltipBubble(
                icon: "🛒",
                title: "The Shop",
                body: "Spend coins to buy new eggs. Rarer eggs cost more but contain rarer animals!",
                buttonText: "Start Studying! 🎉",
                action: { tutorial.finish() }
            )
            .padding(.top, 80)
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Reusable Tooltip Bubble
    
    private func tooltipBubble(
        icon: String,
        title: String,
        body: String,
        buttonText: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(icon)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(body)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Button(action: action) {
                Text(buttonText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.backgroundGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white))
            }
            
            skipButton
        }
        .padding(20)
        .background(cardBackground)
    }
    
    // MARK: - Shared Styles
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(
                LinearGradient(
                    colors: [
                        AppColors.backgroundGreen.opacity(0.95),
                        Color(hex: "#2D5A3F").opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }
    
    private var skipButton: some View {
        Button("Skip Tutorial") {
            tutorial.finish()
        }
        .font(.system(size: 14))
        .foregroundColor(.white.opacity(0.5))
    }
}