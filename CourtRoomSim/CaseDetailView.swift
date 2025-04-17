//
//  CaseDetailView.swift
//  CourtRoomSim
//

import SwiftUI
import CoreData

struct CaseDetailView: View {
    @ObservedObject var caseEntity: CaseEntity
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var navigateToTrial = false
    
    var body: some View {
        VStack(spacing: 16) {
            
            Text(caseEntity.crimeType ?? "Unknown Crime")
                .font(.title)
                .padding(.top, 20)
            
            Text("Phase: \(caseEntity.phase ?? "Unknown")")
                .foregroundColor(.secondary)
            
            if let role = caseEntity.userRole, !role.isEmpty {
                Text("You are the \(role)")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            if let model = caseEntity.aiModel, !model.isEmpty {
                Text("AI Model: \(model)")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            
            Divider().padding(.vertical, 8)
            
            if let scenario = caseEntity.details, !scenario.isEmpty {
                ScrollView {
                    Text(scenario)
                        .padding(.horizontal)
                }
                .frame(minHeight: 120)
            } else {
                Text("No scenario details available.")
                    .foregroundColor(.gray)
            }
            
            if let oc = caseEntity.opposingCounsel {
                Text("Opposing Counsel: \(oc.name ?? "Unknown")")
                    .font(.subheadline)
                    .foregroundColor(.purple)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let victim = caseEntity.victim {
                        let isMurderCrime = (caseEntity.crimeType?.lowercased() == "murder")
                        CharacterSectionView(
                            title: "Victim",
                            character: victim,
                            caseEntity: caseEntity,
                            allowChat: !isMurderCrime
                        )
                    }
                    
                    if let suspect = caseEntity.suspect {
                        CharacterSectionView(
                            title: "Suspect",
                            character: suspect,
                            caseEntity: caseEntity,
                            allowChat: true
                        )
                    }
                    
                    if let opp = caseEntity.opposingCounsel {
                        CharacterSectionView(
                            title: "Opposing Counsel",
                            character: opp,
                            caseEntity: caseEntity,
                            allowChat: true
                        )
                    }
                    
                    if let polSet = caseEntity.police as? Set<CourtCharacter>, !polSet.isEmpty {
                        Text("Police").font(.headline)
                        ForEach(Array(polSet), id: \.id) { officer in
                            CharacterSectionView(
                                title: officer.name ?? "Officer",
                                character: officer,
                                caseEntity: caseEntity,
                                allowChat: true
                            )
                        }
                    }
                    
                    if let witSet = caseEntity.witnesses as? Set<CourtCharacter>, !witSet.isEmpty {
                        Text("Witnesses").font(.headline)
                        ForEach(Array(witSet), id: \.id) { witness in
                            CharacterSectionView(
                                title: witness.name ?? "Witness",
                                character: witness,
                                caseEntity: caseEntity,
                                allowChat: true
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            let currentPhase = caseEntity.phase ?? CasePhase.preTrial.rawValue
            if currentPhase == CasePhase.preTrial.rawValue {
                Button("Proceed to Trial") {
                    caseEntity.phase = CasePhase.trial.rawValue
                    saveContext()
                    navigateToTrial = true
                }
                .font(.headline)
                .padding(.bottom, 16)
                
                NavigationLink(
                    destination: TrialFlowView(caseEntity: caseEntity),
                    isActive: $navigateToTrial
                ) {
                    EmptyView()
                }
                
            } else if currentPhase == CasePhase.trial.rawValue {
                NavigationLink(
                    destination: TrialFlowView(caseEntity: caseEntity),
                    isActive: .constant(true)
                ) {
                    EmptyView()
                }
                .hidden()
            } else if currentPhase == CasePhase.postTrial.rawValue {
                Text("Case is in Post-Trial phase.")
                    .font(.headline)
                    .padding(.bottom, 20)
            } else {
                Text("Unknown Phase: \(currentPhase)")
                    .foregroundColor(.red)
            }
        }
        .navigationBarTitle("Case Detail", displayMode: .inline)
        .onAppear {
            if caseEntity.phase == CasePhase.trial.rawValue {
                navigateToTrial = true
            }
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Failed to save: \(error)")
        }
    }
}

// Same CharacterSectionView from prior code, unchanged

struct CharacterSectionView: View {
    let title: String
    @ObservedObject var character: CourtCharacter
    @ObservedObject var caseEntity: CaseEntity
    
    let allowChat: Bool
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil
    @State private var navigateToChat = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            HStack {
                if let data = character.imageData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .overlay(Text(isGenerating ? "Generating..." : "No Image").font(.caption))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    if let nm = character.name {
                        Text(nm).bold()
                    }
                    
                    if hasChatted(character: character, in: caseEntity) {
                        Text("Chatted")
                            .font(.footnote)
                            .foregroundColor(.green)
                    } else {
                        Text("Not Chatted")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                tappedRow()
            }
            
            if let bg = character.background, !bg.isEmpty {
                Text("Background: \(bg)").font(.subheadline)
            }
            if let pers = character.personality, !pers.isEmpty {
                Text("Personality: \(pers)").font(.subheadline)
            }
            if let mot = character.motivation, !mot.isEmpty {
                Text("Motivation: \(mot)").font(.subheadline)
            }
            
            if let err = errorMessage {
                Text("Error: \(err)").foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .background(
            NavigationLink(
                destination: CharacterChatView(caseEntity: caseEntity, character: character),
                isActive: $navigateToChat
            ) { EmptyView() }
            .hidden()
        )
    }
    
    private func tappedRow() {
        // If image -> chat if allowed. If no image -> generate
        if let data = character.imageData, !data.isEmpty {
            if allowChat {
                navigateToChat = true
            }
        } else {
            regenerateImage()
        }
    }
    
    private func regenerateImage() {
        guard let apiKey = UserDefaults.standard.string(forKey: "openAIKey"), !apiKey.isEmpty else {
            errorMessage = "No OpenAI API key found."
            return
        }
        isGenerating = true
        errorMessage = nil
        
        let prompt = character.imagePrompt ?? "\(character.name ?? "Character") pixel art 16-bit style"
        
        CharacterImageManager.shared.generatePixelArtImage(prompt: prompt, apiKey: apiKey) { result in
            DispatchQueue.main.async {
                self.isGenerating = false
            }
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    character.imageData = data
                    do { try viewContext.save() } catch { print("Error saving new image: \(error)") }
                }
            case .failure(let err):
                DispatchQueue.main.async {
                    self.errorMessage = "Image gen failed: \(err)"
                }
            }
        }
    }
    
    private func hasChatted(character: CourtCharacter, in caseEntity: CaseEntity) -> Bool {
        let req = NSFetchRequest<Conversation>(entityName: "Conversation")
        let predCase = NSPredicate(format: "caseEntity == %@", caseEntity)
        let predChar = NSPredicate(format: "courtCharacter == %@", character)
        req.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predCase, predChar])
        req.fetchLimit = 1
        do {
            let count = try viewContext.count(for: req)
            return (count > 0)
        } catch {
            print("Error checking chat: \(error)")
            return false
        }
    }
}
