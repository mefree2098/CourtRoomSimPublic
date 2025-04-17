//
//  CharacterChatView.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025-04-17.
//

import SwiftUI
import CoreData

struct CharacterChatView: View {
    @ObservedObject var caseEntity: CaseEntity
    @ObservedObject var character: CourtCharacter
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var userMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    @FetchRequest private var messages: FetchedResults<Conversation>
    
    init(caseEntity: CaseEntity, character: CourtCharacter) {
        self.caseEntity = caseEntity
        self.character = character
        
        let req = NSFetchRequest<Conversation>(entityName: "Conversation")
        let predCase = NSPredicate(format: "caseEntity == %@", caseEntity)
        let predChar = NSPredicate(format: "courtCharacter == %@", character)
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predCase, predChar])
        req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        
        _messages = FetchRequest(fetchRequest: req)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Display the character’s image + info at the top
            HStack(spacing: 16) {
                if let data = character.imageData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
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
            
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg, isUser: (msg.sender == "User"))
                                .id(msg.id)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top, 8)
                }
                .onChange(of: messages.count) { _ in
                    // auto-scroll to the latest
                    if let last = messages.last {
                        withAnimation {
                            scrollProxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            if let err = errorMessage {
                Text("Error: \(err)")
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
            if isLoading {
                ProgressView("Waiting for response...")
                    .padding(.bottom, 8)
            }
            
            Divider()
            HStack {
                TextField("Type your message...", text: $userMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 40)
                
                Button("Send") {
                    guard !userMessage.isEmpty else { return }
                    sendUserMessage(userMessage)
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .navigationTitle(character.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendUserMessage(_ text: String) {
        let newMsg = Conversation(context: viewContext)
        newMsg.id = UUID()
        newMsg.sender = "User"
        newMsg.message = text
        newMsg.timestamp = Date()
        newMsg.phase = caseEntity.phase ?? CasePhase.preTrial.rawValue
        newMsg.caseEntity = caseEntity
        newMsg.courtCharacter = character
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving user msg: \(error)")
        }
        
        isLoading = true
        errorMessage = nil
        
        let conversationSoFar = buildSystemAndHistory()
        callOpenAIChat(messages: conversationSoFar) { result in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            switch result {
            case .success(let reply):
                DispatchQueue.main.async {
                    let aiMsg = Conversation(context: self.viewContext)
                    aiMsg.id = UUID()
                    aiMsg.sender = self.character.name ?? "Character"
                    aiMsg.message = reply
                    aiMsg.timestamp = Date()
                    aiMsg.phase = self.caseEntity.phase ?? CasePhase.preTrial.rawValue
                    aiMsg.caseEntity = self.caseEntity
                    aiMsg.courtCharacter = self.character
                    
                    do {
                        try self.viewContext.save()
                    } catch {
                        print("Error saving AI msg: \(error)")
                    }
                    self.userMessage = ""
                }
            case .failure(let err):
                DispatchQueue.main.async {
                    self.errorMessage = "AI error: \(err.localizedDescription)"
                }
            }
        }
    }
    
    private func buildSystemAndHistory() -> [[String: String]] {
        let scenario = caseEntity.details ?? ""
        let role = caseEntity.userRole ?? "Defense"
        let userName = UserProfileManager.shared.playerName.isEmpty ? "User" : UserProfileManager.shared.playerName
        
        let systemPrompt = """
        You are \(character.name ?? "Character"). 
        Scenario: \(scenario)
        The user is the \(role). 
        Stay in character, no disclaimers. 
        Address the user as \(userName).
        """
        
        var result: [[String: String]] = []
        result.append(["role": "system", "content": systemPrompt])
        
        for msg in messages {
            let messageRole = (msg.sender == "User") ? "user" : "assistant"
            result.append(["role": messageRole, "content": msg.message ?? ""])
        }
        return result
    }
    
    private func callOpenAIChat(messages: [[String: String]], completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = UserDefaults.standard.string(forKey: "openAIKey"), !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "OpenAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing API key"])))
            return
        }
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(NSError(domain: "OpenAI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": messages,
            "temperature": 0.7
        ]
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: req) { data, response, error in
            if let err = error {
                completion(.failure(err))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "OpenAI", code: 3, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                let obj = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                guard let choices = obj?["choices"] as? [[String: Any]],
                      let first = choices.first,
                      let msg = first["message"] as? [String: Any],
                      let content = msg["content"] as? String
                else {
                    throw NSError(domain: "OpenAI", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid response structure"])
                }
                completion(.success(content))
            } catch {
                completion(.failure(error))
            }
        }.resume()
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
