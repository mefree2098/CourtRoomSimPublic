//
//  PersistenceController.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025-04-13.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()
    
    // 1) Add a static preview property for SwiftUI previews
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 2) (Optional) Create sample data for previews
        let sampleCase = CaseEntity(context: viewContext)
        sampleCase.id = UUID()
        sampleCase.crimeType = "Preview Crime"
        sampleCase.phase = "PreTrial"
        sampleCase.dateCreated = Date()

        // Possibly add characters, etc. so previews have data.
        let previewCharacter = CourtCharacter(context: viewContext)
        previewCharacter.id = UUID()
        previewCharacter.name = "Preview Witness"
        sampleCase.addToWitnesses(previewCharacter)

        do {
            try viewContext.save()
        } catch {
            print("Failed to save preview data: \(error)")
        }
        
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CourtRoomSim")
        // Ensure "CourtRoomSim" matches your .xcdatamodeld filename (minus extension)
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
