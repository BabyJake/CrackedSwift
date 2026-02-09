//
//  AppExclusionView.swift
//  CrackedSwift
//
//  Allows users to customize which apps are excluded from blocking
//  (i.e., which apps won't crack the egg if opened during focus)
//

import SwiftUI
import FamilyControls

struct AppExclusionView: View {
    @Binding var isPresented: Bool
    @State private var selection = FamilyActivitySelection()
    @StateObject private var screenTime = ScreenTimeManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGreen
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 16) {
                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Customize App Blocking", systemImage: "app.badge.checkmark")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Selected apps WILL crack your egg if opened during focus. Deselect apps you want to exclude (like Calculator, Notes, or Music).")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding()
                    .background(Color.blue.opacity(0.3))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Info about Cracked
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        
                        Text("Tip: Make sure \"Cracked\" is deselected so it doesn't count as leaving. You can also deselect other apps you want to use during study sessions.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal)
                    
                    FamilyActivityPicker(selection: $selection)
                }
                .navigationTitle("App Blocking Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppColors.backgroundGreen, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            // Save the exclusion list (inverted: these are apps that WON'T trigger cracking)
                            // We need to save what's excluded, then ScreenTimeManager will use the inverse
                            saveExclusions()
                            isPresented = false
                        }
                        .foregroundColor(.blue)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .foregroundColor(.white)
                    }
                }
                .onAppear {
                    // Load current monitored apps (apps that will trigger cracking)
                    // User can deselect apps they want to exclude
                    if let loaded = screenTime.loadSelection() {
                        selection = loaded
                    }
                }
            }
        }
    }
    
    private func saveExclusions() {
        // Save the selection - these are the apps that are EXCLUDED (won't crack egg)
        // ScreenTimeManager needs to invert this: block all apps EXCEPT these
        // But actually, ScreenTimeManager monitors the selected apps, so we need to:
        // 1. Get all apps on device (we can't, but we have the total count from initial setup)
        // 2. Subtract the excluded apps from the total
        // 3. Save that as the new selection
        
        // For now, we'll save the exclusion list and ScreenTimeManager will need to handle inversion
        // Actually, let's think about this differently:
        // - Initial setup: user selects ALL apps except Cracked → saved as "apps to monitor"
        // - Settings: user wants to exclude MORE apps → we need to remove those from monitoring
        
        // The simplest approach: save the exclusion selection, and when starting monitoring,
        // ScreenTimeManager will need to get all apps and subtract the excluded ones
        
        // But we can't get "all apps" programmatically. So we'll:
        // Save the excluded apps list separately, and when monitoring starts,
        // use the original "all apps" selection but filter out the excluded ones
        
        // Actually, let's use a simpler approach:
        // Save the current selection as-is. The selection represents apps that WILL be monitored.
        // If user excludes Calculator, we remove Calculator from the selection.
        // So the selection = apps that WILL crack the egg if opened.
        
        // Get the total app count from initial setup
        if let totalAppCount = screenTime.loadTotalAppCount() {
            // Current selection = apps to monitor (will crack if opened)
            // Excluded apps = total - current selection
            let excludedCount = totalAppCount - selection.applicationTokens.count
            
            // Save the selection (apps that WILL trigger cracking)
            screenTime.saveSelection(selection, totalAppCount: totalAppCount)
            
            print("[AppExclusion] Saved: \(selection.applicationTokens.count) apps will trigger cracking, \(excludedCount) apps excluded")
        } else {
            // Fallback: just save the selection
            screenTime.saveSelection(selection, totalAppCount: selection.applicationTokens.count + 1)
        }
    }
}
