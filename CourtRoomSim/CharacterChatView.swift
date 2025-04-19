// CharacterChatView.swift
// CourtRoomSim

import SwiftUI
import UIKit
import CoreData

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
            format: "caseEntity == %@ AND courtCharacter == %@",
            caseEntity, character
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
                header
                Divider()
                chatHistory
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
                inputBar
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
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            )
        }
        .id("chat-\(caseEntity.id!.uuidString)-\(character.id!.uuidString)")
    }

    // MARK: UI Components

    private var header: some View {
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
    }

    private var chatHistory: some View {
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
    }

    private var inputBar: some View {
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

    // MARK: Actions

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
        try? viewContext.save()

        // Gather **full** appropriate context
        let scenario = caseEntity.details ?? ""
        let role = caseEntity.userRole ?? ""
        // Fetch entire conversation for this phase
        let convFetch: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        convFetch.predicate = NSPredicate(
            format: "caseEntity == %@ AND phase == %@",
            caseEntity,
            caseEntity.phase ?? CasePhase.preTrial.rawValue
        )
        convFetch.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        let fullHistory = (try? viewContext.fetch(convFetch))?
            .map { "\($0.sender ?? ""): \($0.message ?? "")" }
            .joined(separator: "\n") ?? ""

        isLoading = true
        errorMessage = nil

        let systemPrompt = """
        You are \(character.name ?? "Character"), a participant in this case.
        Scenario: \(scenario)
        The user is the \(role).
        Conversation so far (all parties):
        \(fullHistory)
        Stay in character, no disclaimers.
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

// MARK: Chat Bubble

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
