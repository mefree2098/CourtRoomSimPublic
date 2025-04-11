//
//  CourtRoomSimApp.swift
//  CourtRoomSim
//
//  Created by Matt Freestone on 4/11/25.
//

import SwiftUI

@main
struct CourtRoomSimApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
