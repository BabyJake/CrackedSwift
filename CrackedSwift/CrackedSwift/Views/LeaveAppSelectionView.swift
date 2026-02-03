//
//  LeaveAppSelectionView.swift
//  CrackedSwift
//
//  Screen Time app picker: choose which apps count as "leaving" the focus session.
//  If the user uses any of these apps, the egg cracks / piggybank shatters when they return.
//  Locking the phone does not use another app, so it does not crack.
//

import SwiftUI
import FamilyControls

struct LeaveAppSelectionView: View {
    @Binding var isPresented: Bool
    @State private var selection = FamilyActivitySelection()
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("If you use any of these apps during a focus session, your egg will crack or piggybank will shatter when you return. Locking your phone does not count.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                FamilyActivityPicker(selection: $selection)
            }
            .navigationTitle("Apps That Count as Leaving")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        ScreenTimeManager.shared.saveSelection(selection)
                        isPresented = false
                    }
                }
            }
            .onAppear {
                if let loaded = ScreenTimeManager.shared.loadSelection() {
                    selection = loaded
                }
            }
        }
    }
}
