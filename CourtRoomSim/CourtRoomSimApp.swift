//
//  CourtRoomSimApp.swift
//  CourtRoomSim
//

import SwiftUI

@main
struct CourtRoomSimApp: App {

    // ── Core‑Data stack shared across the app ──────────────────────────
    private let persistenceController = PersistenceController.shared

    // ── Root‑level view‑model (used to create new cases) ───────────────
    @StateObject private var creator = CaseCreatorViewModel()   // ← fixed

    // ── Scene graph ────────────────────────────────────────────────────
    var body: some Scene {
        WindowGroup {
            CaseListView(viewModel: creator)                     // label OK
                .environment(\.managedObjectContext,
                              persistenceController.container.viewContext)
        }
    }
}
