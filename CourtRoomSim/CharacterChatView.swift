// CharacterChatView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct CharacterChatView: View {
    @ObservedObject var caseEntity: CaseEntity
    @ObservedObject var character: CourtCharacter
    @Environment(\.managedObjectContext) private var viewContext

    @State private var userMessage = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    @FetchRequest private var messages: FetchedResults<Conversation>

    init(caseEntity: CaseEntity, character: CourtCharacter) {
        self.caseEntity = caseEntity
        self.character  = character

        let req = NSFetchRequest<Conversation>(entityName: "Conversation")
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "caseEntity == %@", caseEntity),
            NSPredicate(format: "courtCharacter == %@", character)
        ])
        req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        _messages = FetchRequest(fetchRequest: req)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Character header
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
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()

            // Chat history
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg,
                                       isUser: msg.sender == UserProfileManager.shared.playerName)
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
                    .padding(.vertical, 8)
            }

            Divider()

            // Input field
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
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle(character.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendUserMessage() {
        let text = userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // 1) Save the user's message
        let userMsg = Conversation(context: viewContext)
        userMsg.id             = UUID()
        userMsg.sender         = UserProfileManager.shared.playerName
        userMsg.message        = text
        userMsg.timestamp      = Date()
        userMsg.phase          = caseEntity.phase ?? CasePhase.preTrial.rawValue
        userMsg.caseEntity     = caseEntity
        userMsg.courtCharacter = character
        try? viewContext.save()

        // 2) Prepare AI call
        isLoading    = true
        errorMessage = nil

        // Build system instructions + history
        let scenario = caseEntity.details ?? ""
        let role     = caseEntity.userRole ?? "Defense"
        let userName = UserProfileManager.shared.playerName

        // Flatten prior messages into a single history string
        let historyLines = messages.map { "\($0.sender): \($0.message ?? "")" }
        let historyBlock = historyLines.joined(separator: "\n")

        let systemPrompt = """
        You are \(character.name ?? "Character").
        Scenario: \(scenario)
        The user is the \(role).
        Stay in character, no disclaimers.
        Address the user as \(userName).

        Conversation so far:
        \(historyBlock)
        """

        // 3) Invoke Responses API
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
                    aiMsg.id             = UUID()
                    aiMsg.sender         = character.name
                    aiMsg.message        = reply
                    aiMsg.timestamp      = Date()
                    aiMsg.phase          = caseEntity.phase ?? CasePhase.preTrial.rawValue
                    aiMsg.caseEntity     = caseEntity
                    aiMsg.courtCharacter = character
                    try? viewContext.save()
                    userMessage = ""
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
