// PreTrialChatView.swift
// CourtRoomSim

import SwiftUI
import CoreData
import UIKit

struct PreTrialChatView: View {
    @ObservedObject var caseEntity: CaseEntity
    @ObservedObject var character: CourtCharacter
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var newMessageText = ""
    @State private var showNotebook = false

    @FetchRequest private var messages: FetchedResults<Conversation>

    init(caseEntity: CaseEntity, character: CourtCharacter) {
        self.caseEntity = caseEntity
        self.character = character

        let request = NSFetchRequest<Conversation>(entityName: "Conversation")
        let predCase = NSPredicate(format: "caseEntity.id == %@", caseEntity.id! as CVarArg)
        let predPhase = NSPredicate(format: "phase == %@", CasePhase.preTrial.rawValue)
        let predCharacter = NSPredicate(format: "courtCharacter.id == %@", character.id! as CVarArg)
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
                    let text = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
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
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showNotebook = true }) {
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
        // Dismiss keyboard on any tap without blocking interactions
        .simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
            }
        )
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
        try? viewContext.save()
    }
}

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
                    (msg.sender == UserProfileManager.shared.playerName)
                    ? Color.blue.opacity(0.1)
                    : Color.gray.opacity(0.15)
                )
                .cornerRadius(8)
        }
    }
}
