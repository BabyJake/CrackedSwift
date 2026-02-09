//
//  ScreenTimeRequiredView.swift
//  CrackedSwift
//
//  One-time setup screen: user must grant Screen Time access and select ALL apps
//  to block during focus sessions. This is required before using the app.
//

import SwiftUI

struct ScreenTimeRequiredView: View {
    @ObservedObject private var screenTime = ScreenTimeManager.shared
    @State private var showAppPicker = false
    @State private var isRequestingAuthorization = false
    
    var body: some View {
        Group {
            if screenTime.authorizationGranted == nil || isRequestingAuthorization {
                requestingView
            } else if screenTime.authorizationGranted == false {
                deniedView
            } else if !screenTime.hasSelectedApps {
                selectAppsView
            } else {
                // Should not reach here; parent shows ContentView when hasCompletedSetup
                EmptyView()
            }
        }
        .sheet(isPresented: $showAppPicker) {
            LeaveAppSelectionView(isPresented: $showAppPicker)
        }
        .onAppear {
            if screenTime.authorizationGranted == nil && !isRequestingAuthorization {
                isRequestingAuthorization = true
                Task { @MainActor in
                    await screenTime.requestAuthorization()
                    isRequestingAuthorization = false
                }
            }
        }
    }
    
    private var requestingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Setting up Screen Time…")
                .font(.headline)
            Text("This app needs Screen Time access to block all other apps during focus sessions.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var deniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "hourglass.badge.plus")
                .font(.system(size: 56))
                .foregroundColor(.orange)
            Text("Screen Time Required")
                .font(.title2.bold())
            Text("Cracked needs Screen Time access to block all other apps during your focus sessions. Please enable it to continue.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            VStack(spacing: 12) {
                Button("Try Again") {
                    Task { @MainActor in
                        isRequestingAuthorization = true
                        await screenTime.requestAuthorization()
                        isRequestingAuthorization = false
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var selectAppsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.app.dashed")
                .font(.system(size: 56))
                .foregroundColor(.orange)
            
            Text("Block All Apps")
                .font(.title2.bold())
            
            Text("During focus sessions, all other apps will be blocked. If you open any blocked app, your egg will crack.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            VStack(alignment: .leading, spacing: 8) {
                Label("One-time setup:", systemImage: "1.circle.fill")
                    .font(.subheadline.bold())
                Text("1. Tap \"All Apps & Categories\"\n2. Deselect only \"Cracked\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            
            Button("Set Up App Blocking") {
                showAppPicker = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
