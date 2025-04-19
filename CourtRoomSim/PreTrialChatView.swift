// PreTrialChatView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct PreTrialChatView: View {
    @ObservedObject var caseEntity: CaseEntity
    @ObservedObject var character: CourtCharacter
    @Environment(\.managedObjectContext) private var viewContext
    @State private var newMessageText = ""
    @State private var showNotebook = false

    @FetchRequest private var messages: FetchedResults<Conversation>

    init(caseEntity: CaseEntity, character: CourtCharacter) {
        self.caseEntity = caseEntity
        self.character = character

        let request = NSFetchRequest<Conversation>(entityName: "Conversation")
        let predCase = NSPredicate(format: "caseEntity == %@", caseEntity)
        let predPhase = NSPredicate(format: "phase == %@", CasePhase.preTrial.rawValue)
        let predCharacter = NSPredicate(format: "courtCharacter == %@", character)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predCase, predPhase, predCharacter])
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        _messages = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            PreTrialChatRowView(msg: msg)
                                .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            HStack {
                TextField("Ask a question...", text: $newMessageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send") {
                    guard !newMessageText.isEmpty else { return }
                    let text = newMessageText
                    newMessageText = ""
                    addPreTrialMessage(text: text)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle(character.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNotebook = true
                } label: {
                    Image(systemName: "book")
                        .imageScale(.large)
                        .accessibilityLabel("Notebook")
                }
            }
        }
        .sheet(isPresented: $showNotebook) {
            NotebookView(caseEntity: caseEntity)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    private func addPreTrialMessage(text: String) {
        let newMsg = Conversation(context: viewContext)
        newMsg.id = UUID()
        newMsg.sender = UserProfileManager.shared.playerName
        newMsg.message = text
        newMsg.timestamp = Date()
        newMsg.phase = CasePhase.preTrial.rawValue
        newMsg.caseEntity = caseEntity
        newMsg.courtCharacter = character
        do {
            try viewContext.save()
        } catch {
            print("Error saving pre-trial message: \(error)")
        }
    }
}

struct PreTrialChatRowView: View {
    let msg: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(msg.sender ?? "Unknown")
                .font(.caption)
                .foregroundColor(.gray)
            Text(msg.message ?? "")
                .padding(10)
                .background(
                    msg.sender == UserProfileManager.shared.playerName
                    ? Color.blue.opacity(0.1)
                    : Color.gray.opacity(0.15)
                )
                .cornerRadius(8)
        }
    }
}
