//
//  SettingsView.swift
//  CrackedSwift
//
//  Settings menu for customizing app blocking behavior
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var screenTime = ScreenTimeManager.shared
    @State private var showingAppExclusion = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGreen
                    .ignoresSafeArea()
                
                List {
                    Section {
                        HStack {
                            Image(systemName: "app.badge")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("App Blocking")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                if let selection = screenTime.loadSelection(),
                                   let totalCount = screenTime.loadTotalAppCount() {
                                    let monitoredCount = selection.applicationTokens.count
                                    let excludedCount = totalCount - monitoredCount
                                    Text("\(monitoredCount) apps monitored, \(excludedCount) excluded")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else {
                                    Text("Choose which apps won't count as leaving")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showingAppExclusion = true
                            }) {
                                Text("Edit")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Focus Session Settings")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .listRowBackground(Color.white.opacity(0.1))
                    
                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("How It Works")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Apps that are NOT excluded will crack your egg if you open them during a focus session. Locking your phone is safe.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Information")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .listRowBackground(Color.white.opacity(0.1))
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundGreen, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showingAppExclusion) {
                AppExclusionView(isPresented: $showingAppExclusion)
            }
        }
    }
}
