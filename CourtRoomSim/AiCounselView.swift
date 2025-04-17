// AiCounselView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct AiCounselView: View {
    // Injected
    let roleName: String
    @ObservedObject var caseEntity: CaseEntity
    let recordTranscript: (String, String) -> Void
    let gptWitnessAnswer: (String, String, String, @escaping (String) -> Void) -> Void
    let onFinishCase: () -> Void

    // Local state
    @State private var currentIndex = 0
    @State private var currentWitness: CourtCharacter?
    @State private var contextSummary = ""
    @State private var askedQuestions: [String] = []
    @State private var pendingQuestion = ""
    @State private var awaitingUser = false
    @State private var showObj = false
    @State private var objReason = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 16) {
            Text(roleName).font(.headline)

            if awaitingUser {
                Text(pendingQuestion).padding()
                HStack {
                    Button("Object") { showObj = true }
                    Spacer()
                    Button("Proceed") { allowAnswer() }
                }
                .padding(.horizontal)
            }
            else if isLoading {
                ProgressView()
            }
            else if currentWitness == nil {
                Text("\(roleName) finished questioning.")
                Button("Continue") { onFinishCase() }
            }
            else {
                Button("Proceed") {
                    askQuestion()
                }
                .disabled(isLoading)
            }
        }
        .alert("Objection", isPresented: $showObj) {
            TextField("Reason", text: $objReason)
            Button("Submit") { handleObjection() }
            Button("Cancel", role: .cancel) {}
        }
        .padding()
        .onAppear { nextWitness() }
    }

    private func askQuestion() {
        guard let w = currentWitness else { return }
        isLoading = true
        let systemPrompt = """
        You are \(roleName) under the judge’s supervision. \
        Ask exactly ONE concise question of \(w.name ?? "the witness") based on context. \
        Do not repeat or bundle questions.
        """
        let userPrompt = """
        Context: \(contextSummary)
        Already asked: \(askedQuestions.joined(separator: " | "))
        """
        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: userPrompt
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let q):
                    let clean = q.trimmingCharacters(in: .whitespacesAndNewlines)
                    if askedQuestions.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) {
                        recordTranscript("Judge", "No further questions, your honor.")
                        onFinishCase()
                    } else {
                        pendingQuestion = clean
                        awaitingUser = true
                    }
                case .failure:
                    recordTranscript("Judge", "Counsel, please proceed.")
                    onFinishCase()
                }
            }
        }
    }

    private func allowAnswer() {
        guard let w = currentWitness else { return }
        recordTranscript(roleName, pendingQuestion)
        awaitingUser = false
        askedQuestions.append(pendingQuestion)

        gptWitnessAnswer(w.name ?? "", pendingQuestion, contextSummary) { ans in
            recordTranscript(w.name ?? "", ans)
            contextSummary += "Q: \(pendingQuestion)\nA: \(ans)\n"
            // Delay so user sees answer before next popup
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                askQuestion()
            }
        }
    }

    private func handleObjection() {
        let sustained = Bool.random()
        recordTranscript("Judge", "Objection (\(objReason)). Judge: \(sustained ? "Sustained" : "Overruled")")
        objReason = ""
        if sustained {
            // Delay before next question popup
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                askQuestion()
            }
        } else {
            allowAnswer()
        }
    }

    private func nextWitness() {
        let all = (caseEntity.witnesses as? Set<CourtCharacter> ?? [])
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
        if currentIndex < all.count {
            currentWitness = all[currentIndex]
            contextSummary = ""
            askedQuestions = []
            currentIndex += 1
        } else {
            currentWitness = nil
        }
    }
}
