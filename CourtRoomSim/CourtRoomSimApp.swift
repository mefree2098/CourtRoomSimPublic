// CourtRoomSimApp.swift
// CourtRoomSim

import SwiftUI

@main
struct CourtRoomSimApp: App {
    // Shared Core Data persistence controller
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            NavigationView {
                CasesListView()
                Text("Select or create a case")
                    .foregroundColor(.secondary)
            }
            .environment(
                \.managedObjectContext,
                persistenceController.container.viewContext
            )
        }
    }
}
