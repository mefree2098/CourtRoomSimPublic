//
//  TrialChatView.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025-04-13.
//

import SwiftUI
import CoreData

struct TrialChatView: View {
    @ObservedObject var caseEntity: CaseEntity
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var newMessageText: String = ""
    @FetchRequest private var messages: FetchedResults<Conversation>
    
    init(caseEntity: CaseEntity) {
        self.caseEntity = caseEntity
        
        let request = NSFetchRequest<Conversation>(entityName: "Conversation")
        let predCase = NSPredicate(format: "caseEntity == %@", caseEntity)
        let predPhase = NSPredicate(format: "phase == %@", CasePhase.trial.rawValue)
        
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [predCase, predPhase])
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
                            TrialChatRowView(msg: msg)
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
                TextField("Speak in court...", text: $newMessageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send") {
                    guard !newMessageText.isEmpty else { return }
                    addTrialMessage(text: newMessageText)
                    newMessageText = ""
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle("Trial in Progress")
    }
    
    private func addTrialMessage(text: String) {
        let newMsg = Conversation(context: viewContext)
        newMsg.id = UUID()
        newMsg.sender = "User"
        newMsg.message = text
        newMsg.timestamp = Date()
        newMsg.phase = CasePhase.trial.rawValue
        
        newMsg.caseEntity = caseEntity
        newMsg.courtCharacter = nil
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving trial message: \(error)")
        }
    }
}

// MARK: - Row View
struct TrialChatRowView: View {
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
