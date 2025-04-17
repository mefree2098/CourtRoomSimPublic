// CourtRoomSimApp.swift

import SwiftUI

@main
struct CourtRoomSimApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var profile = UserProfileManager.shared

    // Track whether Settings should appear on launch
    @State private var showSettingsOnLaunch: Bool

    init() {
        // Determine if we need to force SettingsView
        let apiKeyMissing = (UserDefaults.standard.string(forKey: "openAIKey") ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        let nameMissing   = UserProfileManager.shared.playerName.trimmingCharacters(in: .whitespaces).isEmpty
        _showSettingsOnLaunch = State(initialValue: apiKeyMissing || nameMissing)
    }

    var body: some Scene {
        WindowGroup {
            // Root is your Case List
            CaseListView(viewModel: CaseCreatorViewModel())
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .sheet(isPresented: $showSettingsOnLaunch) {
                    SettingsView()
                }
                .onChange(of: profile.playerName) { _ in
                    // If the user enters a name, dismiss settings
                    if !profile.playerName.trimmingCharacters(in: .whitespaces).isEmpty,
                       !(UserDefaults.standard.string(forKey: "openAIKey") ?? "").isEmpty {
                        showSettingsOnLaunch = false
                    }
                }
                .onChange(of: UserDefaults.standard.string(forKey: "openAIKey")) { _ in
                    let missing = (UserDefaults.standard.string(forKey: "openAIKey") ?? "").trimmingCharacters(in: .whitespaces).isEmpty
                    if !missing && !profile.playerName.trimmingCharacters(in: .whitespaces).isEmpty {
                        showSettingsOnLaunch = false
                    }
                }
        }
    }
}
