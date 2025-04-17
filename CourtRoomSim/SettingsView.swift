//
//  SettingsView.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025-04-15.
//

import SwiftUI

struct SettingsView: View {
    
    @Environment(\.presentationMode) private var presentationMode
    @State private var showProfileEditor = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Button("Edit My Profile") {
                        showProfileEditor = true
                    }
                }
                Section {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showProfileEditor) {
                UserProfileView()
            }
        }
    }
}
