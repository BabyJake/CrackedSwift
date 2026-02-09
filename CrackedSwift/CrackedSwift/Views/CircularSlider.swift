//
//  CircularSlider.swift
//  CrackedSwift
//
//  Circular slider with draggable knob that fills the circle
//

import SwiftUI

struct CircularSlider: View {
    @Binding var selectedMinutes: Int
    @Binding var isTimerRunning: Bool
    
    // Timer progress tracking
    var timeRemaining: TimeInterval = 0
    var initialDuration: TimeInterval = 0
    
    // Current egg image name
    var currentEggImageName: String = "FarmEgg"
    
    // Time options: 5–120 minutes in 5-minute steps
    let minMinutes: Int = 5
    let maxMinutes: Int = 120
    let stepMinutes: Int = 5
    
    @State private var angle: Double = 0
    @State private var isDragging: Bool = false
    @State private var showEgg: Bool = false
    
    private let strokeWidth: CGFloat = 8
    private var circleSize: CGFloat = 200
    private var radius: CGFloat {
        // Radius should be at the center of the stroke (half circle size minus half stroke width)
        return (circleSize / 2) - (strokeWidth / 2)
    }
    
    init(selectedMinutes: Binding<Int>, isTimerRunning: Binding<Bool>, timeRemaining: TimeInterval = 0, initialDuration: TimeInterval = 0, currentEggImageName: String = "FarmEgg") {
        self._selectedMinutes = selectedMinutes
        self._isTimerRunning = isTimerRunning
        self.timeRemaining = timeRemaining
        self.initialDuration = initialDuration
        self.currentEggImageName = currentEggImageName
    }
    
    var body: some View {
        ZStack {
            // Outermost circle (muted green/khaki)
            Circle()
                .fill(AppColors.circleGreen2)
                .frame(width: 280, height: 280)
            
            // Middle circle (muted beige/tan)
            Circle()
                .fill(AppColors.circleBeige)
                .frame(width: 240, height: 240)
            
            // Track circle (light pastel green - base)
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 8)
                .frame(width: circleSize, height: circleSize)
            
            // Timer progress circle (when timer is running) - shows time remaining
            if isTimerRunning && initialDuration > 0 {
                Circle()
                    .trim(from: 0, to: timerProgress)
                    .stroke(AppColors.buttonGreen, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(-90)) // Start from top
                    .animation(.linear(duration: 0.5), value: timerProgress)
            } else {
                // Filled progress circle (when timer is not running) - shows selected time
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(AppColors.buttonGreen, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(-90)) // Start from top
            }
            
            // Draggable knob (disabled when timer is running)
            GeometryReader { geometry in
                knobView
                    .position(knobPosition(in: geometry))
                    .gesture(isTimerRunning ? nil : dragGesture(in: geometry))
                    .opacity(isTimerRunning ? 0 : 1.0)
            }
            .frame(width: circleSize, height: circleSize)
            
            // Nest image in center (always visible, behind egg)
            Group {
                if UIImage(named: "nest") != nil {
                    Image("nest")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 120)
                } else {
                    // Fallback nest image
                    Image(systemName: "circle.grid.2x2.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .offset(y: 35) // Move nest down
            .transition(.opacity)
            
            // Egg image that appears when timer starts (in front of nest, smaller to fit inside)
            if showEgg {
                Group {
                    if currentEggImageName == "Piggybank" {
                        // Special handling for piggybank - use asset
                        if UIImage(named: "PiggyBank") != nil {
                            Image("PiggyBank")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                        } else {
                            Image(systemName: "oval.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    } else if UIImage(named: currentEggImageName) != nil {
                        Image(currentEggImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                    } else {
                        // Fallback egg image
                        Image(systemName: "oval.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .offset(y: -5) // Slight upward offset to center in nest
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 280, height: 280)
        .onAppear {
            updateAngleFromMinutes()
        }
        .onChange(of: selectedMinutes) { oldValue, newValue in
            if !isDragging {
                updateAngleFromMinutes()
            }
        }
        .onChange(of: isTimerRunning) { oldValue, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showEgg = newValue
            }
        }
    }
    
    private var progress: CGFloat {
        let totalRange = Double(maxMinutes - minMinutes)
        let currentProgress = Double(selectedMinutes - minMinutes) / totalRange
        return CGFloat(currentProgress)
    }
    
    private var timerProgress: CGFloat {
        guard initialDuration > 0 else { return 0 }
        let progress = timeRemaining / initialDuration
        return CGFloat(max(0, min(1, progress))) // Clamp between 0 and 1
    }
    
    private func knobPosition(in geometry: GeometryProxy) -> CGPoint {
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        // The progress circle is rotated -90 degrees to start from top
        // Our angle represents progress from 0-360 where 0 = top
        // In SwiftUI coordinate system: 0° = right, 90° = bottom, 180° = left, 270° = top
        // So to convert our angle (0 = top) to coordinate system: add 270 or subtract 90
        // Since we want: our 0° (top) → coordinate -90° (top)
        let adjustedAngle = angle - 90.0
        let angleRadians = adjustedAngle * .pi / 180.0
        let x = center.x + radius * cos(angleRadians)
        let y = center.y + radius * sin(angleRadians)
        return CGPoint(x: x, y: y)
    }
    
    private var knobView: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)
            Circle()
                .fill(AppColors.buttonGreen)
                .frame(width: 18, height: 18)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDragging = true
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let deltaX = value.location.x - center.x
                let deltaY = value.location.y - center.y
                
                // Calculate angle from center (atan2 gives angle from positive x-axis)
                // We want 0 degrees at top, so we adjust
                var newAngle = atan2(deltaY, deltaX) * 180 / .pi
                newAngle += 90 // Adjust to start from top (0 degrees = top)
                if newAngle < 0 {
                    newAngle += 360
                }
                
                angle = newAngle
                updateMinutesFromAngle()
            }
            .onEnded { _ in
                isDragging = false
                snapToNearestStep()
            }
    }
    
    private func updateMinutesFromAngle() {
        // Convert angle (0-360) to progress (0-1)
        let normalizedAngle = angle.truncatingRemainder(dividingBy: 360)
        let progress = normalizedAngle / 360.0
        
        // Convert progress to minutes
        let totalRange = Double(maxMinutes - minMinutes)
        let rawMinutes = Double(minMinutes) + (progress * totalRange)
        
        // Round to nearest step
        let roundedMinutes = Int(round(rawMinutes / Double(stepMinutes))) * stepMinutes
        let clampedMinutes = max(minMinutes, min(maxMinutes, roundedMinutes))
        
        // Only update if it's different to avoid unnecessary updates
        if clampedMinutes != selectedMinutes {
            selectedMinutes = clampedMinutes
        }
    }
    
    private func updateAngleFromMinutes() {
        let totalRange = Double(maxMinutes - minMinutes)
        let progress = Double(selectedMinutes - minMinutes) / totalRange
        angle = progress * 360.0
    }
    
    private func snapToNearestStep() {
        // Ensure we're on a step
        let rounded = ((selectedMinutes + stepMinutes / 2) / stepMinutes) * stepMinutes
        selectedMinutes = max(minMinutes, min(maxMinutes, rounded))
        updateAngleFromMinutes()
    }
}

#Preview {
    ZStack {
        AppColors.backgroundGreen
            .ignoresSafeArea()
        
        CircularSlider(selectedMinutes: .constant(30), isTimerRunning: .constant(false), timeRemaining: 0, initialDuration: 0)
    }
}

