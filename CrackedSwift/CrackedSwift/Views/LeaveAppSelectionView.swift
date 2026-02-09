//
//  LeaveAppSelectionView.swift
//  CrackedSwift
//
//  Screen Time app picker: user must select ALL apps (except CrackedSwift) to block during focus.
//  This is a one-time setup - the selection cannot be changed later.
//
//  Flow:
//  1. User taps "All Apps & Categories" → we record the peak app count as their total
//  2. User deselects only Cracked → current = peak - 1
//  3. We require: current >= (peak - 1) to allow entry
//

import SwiftUI
import FamilyControls

struct LeaveAppSelectionView: View {
    @Binding var isPresented: Bool
    @State private var selection = FamilyActivitySelection()
    
    /// The peak (maximum) number of apps we've seen selected during this session.
    /// When user taps "All", this captures their total app count.
    @State private var peakAppCount: Int = 0
    
    /// Minimum apps required even if peak is low (prevents gaming with very few apps).
    private static let absoluteMinimumApps = 3
    
    /// The required number of apps = peak - 1 (all apps minus Cracked).
    /// If peak is 0 (user hasn't tapped All yet), we show a message to tap All first.
    private var requiredAppCount: Int {
        max(peakAppCount - 1, Self.absoluteMinimumApps)
    }
    
    /// Check if user has selected all apps except Cracked.
    /// They must have tapped "All" first (peak > 0), then have at least (peak - 1) selected.
    private var hasSelectedAllApps: Bool {
        guard peakAppCount > 0 else { return false } // Must tap "All" first
        return selection.applicationTokens.count >= requiredAppCount
    }
    
    /// Status message showing current state
    private var selectionStatusMessage: String {
        if peakAppCount == 0 {
            return "Tap \"All Apps & Categories\" at the top of the list."
        } else if !hasSelectedAllApps {
            return "Tap \"All Apps & Categories\" again, then search \"Cracked\" using search bar at bottom and unselect it."
        }
        return ""
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                // Instructions banner
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Tap \"All Apps & Categories\" at the top")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    Text("2. Search \"Cracked\" and unselect it")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Status message
                if !hasSelectedAllApps {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text(selectionStatusMessage)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All done! Press Done at top right to continue.")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal)
                }
                
                FamilyActivityPicker(selection: $selection)
            }
            .navigationTitle("Block All Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        guard hasSelectedAllApps else { return }
                        // Save both the selection and the peak count for future validation
                        ScreenTimeManager.shared.saveSelection(selection, totalAppCount: peakAppCount)
                        isPresented = false
                    }
                    .disabled(!hasSelectedAllApps)
                    .foregroundColor(hasSelectedAllApps ? .blue : .gray)
                }
            }
            .onChange(of: selection) { oldValue, newValue in
                // Track the peak app count - when user taps "All", this captures their total
                let currentCount = newValue.applicationTokens.count
                if currentCount > peakAppCount {
                    peakAppCount = currentCount
                    print("[LeaveAppSelection] New peak app count: \(peakAppCount)")
                }
            }
            .onAppear {
                // Load existing selection and peak if available
                if let loaded = ScreenTimeManager.shared.loadSelection() {
                    selection = loaded
                }
                if let savedPeak = ScreenTimeManager.shared.loadTotalAppCount() {
                    peakAppCount = savedPeak
                }
            }
        }
    }
}
