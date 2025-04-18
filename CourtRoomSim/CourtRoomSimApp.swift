// CourtRoomSimApp.swift
// CourtRoomSim

import SwiftUI

@main
struct CourtRoomSimApp: App {
    // Use the existing PersistenceController in your project
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            NavigationView {
                CasesListView()
                Text("Select or create a case")
                    .foregroundColor(.secondary)
            }
            .environment(\.managedObjectContext,
                         persistenceController.container.viewContext)
        }
    }
}
