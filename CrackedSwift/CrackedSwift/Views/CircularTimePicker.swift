//
//  CircularTimePicker.swift
//  CrackedSwift
//
//  Circular scrollable time picker similar to Forest app
//

import SwiftUI

struct CircularTimePicker: View {
    @Binding var selectedMinutes: Int
    
    // Time options (in minutes) - similar to Forest app
    let timeOptions: [Int] = [10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 90, 120]
    
    @State private var dragOffset: CGFloat = 0
    @State private var lastDragValue: CGFloat = 0
    
    var body: some View {
        ZStack {
            backgroundCircles
            timePickerContent
        }
        .frame(width: 280, height: 280)
    }
    
    private var backgroundCircles: some View {
        ZStack {
            // Outermost circle (muted green/khaki)
            Circle()
                .fill(AppColors.circleGreen2)
                .frame(width: 280, height: 280)
            
            // Middle circle (muted beige/tan)
            Circle()
                .fill(AppColors.circleBeige)
                .frame(width: 240, height: 240)
            
            // Innermost circle (light pastel green)
            Circle()
                .fill(AppColors.circleGreen1)
                .frame(width: 200, height: 200)
        }
    }
    
    private var timePickerContent: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius: CGFloat = 90
            
            ZStack {
                timeOptionsView(center: center, radius: radius)
                whiteDotIndicator(center: center, radius: radius)
            }
            .rotationEffect(.degrees(Double(dragOffset)))
        }
        .frame(width: 200, height: 200)
        .gesture(dragGesture)
    }
    
    private func timeOptionsView(center: CGPoint, radius: CGFloat) -> some View {
        ForEach(Array(timeOptions.enumerated()), id: \.element) { index, minutes in
            timeOptionView(index: index, minutes: minutes, center: center, radius: radius)
        }
    }
    
    private func timeOptionView(index: Int, minutes: Int, center: CGPoint, radius: CGFloat) -> some View {
        let angle = Double(index) * (2 * .pi / Double(timeOptions.count)) - .pi / 2
        let x = center.x + radius * cos(angle)
        let y = center.y + radius * sin(angle)
        let isSelected = minutes == selectedMinutes
        
        return Text("\(minutes)")
            .font(fontForOption(isSelected: isSelected))
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .frame(width: 40, height: 40)
            .background(backgroundForOption(isSelected: isSelected))
            .position(x: x, y: y)
    }
    
    private func fontForOption(isSelected: Bool) -> Font {
        if isSelected {
            return .system(size: 20, weight: .bold)
        } else {
            return .system(size: 16, weight: .regular)
        }
    }
    
    @ViewBuilder
    private func backgroundForOption(isSelected: Bool) -> some View {
        if isSelected {
            Circle()
                .fill(AppColors.buttonGreen)
                .frame(width: 40, height: 40)
        } else {
            Color.clear
                .frame(width: 0, height: 0)
        }
    }
    
    private func whiteDotIndicator(center: CGPoint, radius: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .position(x: center.x, y: center.y - radius - 20)
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let delta = value.translation.height - lastDragValue
                dragOffset += delta * 0.5
                lastDragValue = value.translation.height
                updateSelection()
            }
            .onEnded { _ in
                lastDragValue = 0
                snapToNearestOption()
            }
    }
    
    private func updateSelection() {
        // Calculate rotation angle
        let normalizedAngle = dragOffset.truncatingRemainder(dividingBy: 360)
        let anglePerOption = 360.0 / Double(timeOptions.count)
        
        // Find closest option
        var closestIndex = 0
        var minDifference = 360.0
        
        for (index, _) in timeOptions.enumerated() {
            let optionAngle = Double(index) * anglePerOption
            let difference = abs(normalizedAngle - optionAngle)
            if difference < minDifference {
                minDifference = difference
                closestIndex = index
            }
        }
        
        selectedMinutes = timeOptions[closestIndex]
    }
    
    private func snapToNearestOption() {
        // Find current selected index
        guard let currentIndex = timeOptions.firstIndex(of: selectedMinutes) else { return }
        
        // Calculate target angle
        let anglePerOption = 360.0 / Double(timeOptions.count)
        let targetAngle = Double(currentIndex) * anglePerOption
        
        // Animate to target angle
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            dragOffset = targetAngle
        }
    }
}

// Circular time picker using Picker wheel style (simpler and more reliable)
struct CircularTimePickerWheel: View {
    @Binding var selectedMinutes: Int
    
    let timeOptions: [Int] = [10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 90, 120]
    
    var body: some View {
        // Picker wheel in the center
        Picker("Time", selection: $selectedMinutes) {
            ForEach(timeOptions, id: \.self) { minutes in
                Text("\(minutes)")
                    .tag(minutes)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .pickerStyle(.wheel)
        .frame(width: 120, height: 80)
        .clipped()
        .accentColor(.white) // Make selection indicator white
    }
}


#Preview {
    CircularTimePickerWheel(selectedMinutes: .constant(30))
}

