// CharacterChatView.swift
// CourtRoomSim
//
// Added tap-to-dismiss keyboard anywhere in the chat view.

import SwiftUI
import CoreData

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

struct CharacterChatView: View {
    @ObservedObject var caseEntity: CaseEntity
    @ObservedObject var character: CourtCharacter
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var userMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showNotebook: Bool = false

    @FetchRequest private var messages: FetchedResults<Conversation>

    init(caseEntity: CaseEntity, character: CourtCharacter) {
        self.caseEntity = caseEntity
        self.character = character
        let predicate = NSPredicate(
            format: "caseEntity.id == %@ AND courtCharacter.id == %@",
            caseEntity.id! as CVarArg,
            character.id! as CVarArg
        )
        _messages = FetchRequest(
            entity: Conversation.entity(),
            sortDescriptors: [NSSortDescriptor(key: "timestamp", ascending: true)],
            predicate: predicate
        )
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 16) {
                    if let data = character.imageData,
                       let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(Text("No Image").font(.caption))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(character.name ?? "Character")
                            .font(.headline)
                        if let pers = character.personality, !pers.isEmpty {
                            Text(pers)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding()
                
                Divider()

                // Chat history
                ScrollViewReader { scroll in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { msg in
                                ChatBubble(
                                    message: msg,
                                    isUser: msg.sender == UserProfileManager.shared.playerName
                                )
                                .id(msg.id)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .onChange(of: messages.count) { _ in
                        if let last = messages.last {
                            withAnimation {
                                scroll.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                if let err = errorMessage {
                    Text("Error: \(err)")
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                if isLoading {
                    ProgressView("Waiting for response…")
                        .padding()
                }

                Divider()

                // Input
                HStack {
                    TextField("Type your message…", text: $userMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(minHeight: 40)
                    Button("Send") {
                        sendUserMessage()
                    }
                    .disabled(userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.leading, 4)
                }
                .padding()
            }
            .navigationTitle(character.name ?? "Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
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
            .onTapGesture {
                hideKeyboard()
            }
        }
        .id("chat-\(caseEntity.id!.uuidString)-\(character.id!.uuidString)")
    }

    private func sendUserMessage() {
        let text = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        userMessage = ""

        // Save user message
        let userMsg = Conversation(context: viewContext)
        userMsg.id = UUID()
        userMsg.sender = UserProfileManager.shared.playerName
        userMsg.message = text
        userMsg.timestamp = Date()
        userMsg.phase = caseEntity.phase ?? CasePhase.preTrial.rawValue
        userMsg.caseEntity = caseEntity
        userMsg.courtCharacter = character
        do { try viewContext.save() } catch { errorMessage = error.localizedDescription }

        // Send to AI
        isLoading = true
        errorMessage = nil

        let scenario = caseEntity.details ?? ""
        let role = caseEntity.userRole ?? ""
        let history = messages.map { "\($0.sender): \($0.message ?? "")" }.joined(separator: "\n")
        let systemPrompt = """
You are \(character.name ?? "Character").

Scenario: \(scenario)

The user is the \(role).

Stay in character, no disclaimers.

Conversation so far:

\(history)
"""

        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: text
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let reply):
                    let aiMsg = Conversation(context: viewContext)
                    aiMsg.id = UUID()
                    aiMsg.sender = character.name
                    aiMsg.message = reply
                    aiMsg.timestamp = Date()
                    aiMsg.phase = caseEntity.phase ?? CasePhase.preTrial.rawValue
                    aiMsg.caseEntity = caseEntity
                    aiMsg.courtCharacter = character
                    try? viewContext.save()
                case .failure(let err):
                    errorMessage = err.localizedDescription
                }
            }
        }
    }
}

struct ChatBubble: View {
    let message: Conversation
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser { Spacer() }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.sender ?? (isUser ? "You" : "Character"))
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(message.message ?? "")
                    .padding(10)
                    .background(isUser ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                    .cornerRadius(10)
            }
            if !isUser { Spacer() }
        }
    }
}
