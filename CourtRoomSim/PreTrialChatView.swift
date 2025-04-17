//
//  PreTrialChatView.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025-04-13.
//

import SwiftUI
import CoreData

struct PreTrialChatView: View {
    @ObservedObject var caseEntity: CaseEntity
    @ObservedObject var character: CourtCharacter
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var newMessageText: String = ""
    @FetchRequest private var messages: FetchedResults<Conversation>
    
    init(caseEntity: CaseEntity, character: CourtCharacter) {
        self.caseEntity = caseEntity
        self.character = character
        
        let request = NSFetchRequest<Conversation>(entityName: "Conversation")
        
        let predCase = NSPredicate(format: "caseEntity == %@", caseEntity)
        let predPhase = NSPredicate(format: "phase == %@", CasePhase.preTrial.rawValue)
        let predCharacter = NSPredicate(format: "courtCharacter == %@", character)
        
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [predCase, predPhase, predCharacter])
        request.predicate = compound
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        _messages = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        VStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            PreTrialChatRowView(msg: msg)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            scrollProxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            HStack {
                TextField("Ask a question...", text: $newMessageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    guard !newMessageText.isEmpty else { return }
                    addPreTrialMessage(text: newMessageText)
                    newMessageText = ""
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle(character.name ?? "Unnamed Character")
    }
    
    private func addPreTrialMessage(text: String) {
        let newMsg = Conversation(context: viewContext)
        newMsg.id = UUID()
        newMsg.sender = "User"
        newMsg.message = text
        newMsg.timestamp = Date()
        newMsg.phase = CasePhase.preTrial.rawValue
        
        // Must be same context (viewContext) for both conversation & caseEntity
        newMsg.caseEntity = caseEntity
        newMsg.courtCharacter = character
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving pre-trial message: \(error)")
        }
    }
}

// MARK: - Row View
struct PreTrialChatRowView: View {
    let msg: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(msg.sender ?? "Unknown Sender")
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(msg.message ?? "No message")
                .padding(10)
                .background(
                    (msg.sender == "User")
                    ? Color.blue.opacity(0.1)
                    : Color.gray.opacity(0.15)
                )
                .cornerRadius(8)
        }
        .id(msg.id)
    }
}
