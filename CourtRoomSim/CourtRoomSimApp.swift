// CourtRoomSimApp.swift
// CourtRoomSim

import SwiftUI
import os
import CoreData

// Create a logger for the app
private let logger = Logger(subsystem: "com.pura.CourtRoomSim", category: "App")

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .symbolEffect(.bounce, options: .repeating)
            
            ProgressView()
                .scaleEffect(1.2)
                .tint(.accentColor)
            
            Text("Preparing Courtroom")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Loading case files...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

struct MainContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            CasesListView()
            Text("Select or create a case")
                .foregroundColor(.secondary)
                .font(.title3)
        }
        .navigationViewStyle(.stack)
    }
}

@main
struct CourtRoomSimApp: App {
    // Create a lightweight persistence controller that doesn't load the store immediately
    @StateObject private var persistenceController = LightweightPersistenceController()
    @State private var isLoading = true
    @State private var isCoreDataReady = false

    init() {
        logger.debug("App initializing")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLoading || !isCoreDataReady {
                    LoadingView()
                        .onAppear {
                            logger.debug("LoadingView appeared")
                            
                            // Initialize Core Data in the background
                            Task {
                                logger.debug("Starting Core Data initialization")
                                await persistenceController.initializeCoreData()
                                logger.debug("Core Data initialization complete")
                                
                                // Transition to main content
                                DispatchQueue.main.async {
                                    isCoreDataReady = true
                                    isLoading = false
                                }
                            }
                        }
                } else {
                    MainContentView()
                        .environment(
                            \.managedObjectContext,
                            persistenceController.container.viewContext
                        )
                        .onAppear {
                            logger.debug("MainContentView appeared")
                        }
                }
            }
            .onAppear {
                logger.debug("WindowGroup onAppear called")
            }
        }
    }
}

// A lightweight persistence controller that doesn't load the store immediately
class LightweightPersistenceController: ObservableObject {
    let container: NSPersistentContainer
    
    init() {
        logger.debug("Creating lightweight persistence controller")
        container = NSPersistentContainer(name: "CourtRoomSim")
    }
    
    func initializeCoreData() async {
        logger.debug("Initializing Core Data store")
        
        // Load the persistent store in the background
        await withCheckedContinuation { continuation in
            container.loadPersistentStores { description, error in
                if let error = error {
                    logger.error("Failed to load Core Data store: \(error.localizedDescription)")
                } else {
                    logger.debug("Core Data store loaded successfully")
                }
                continuation.resume()
            }
        }
        
        // Add any additional setup here
        logger.debug("Core Data setup complete")
    }
}
