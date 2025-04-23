// AiCounselView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct AiCounselView: View {
    let roleName: String
    @ObservedObject var caseEntity: CaseEntity
    let recordTranscript: (String, String) -> Void
    let gptWitnessAnswer: (String, String, String, @escaping (String) -> Void) -> Void
    let onFinishCase: () -> Void

    @State private var currentIndex = 0
    @State private var currentWitness: CourtCharacter?
    @State private var contextSummary = ""
    @State private var askedQuestions: [String] = []
    @State private var pendingQuestion = ""
    @State private var awaitingUser = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Objection sheet
    @State private var showObjectionInput = false
    @State private var objectionText = ""

    private let questionLimit = 5

    @FetchRequest private var messages: FetchedResults<Conversation>
    init(
        roleName: String,
        caseEntity: CaseEntity,
        recordTranscript: @escaping (String, String) -> Void,
        gptWitnessAnswer: @escaping (String, String, String, @escaping (String) -> Void) -> Void,
        onFinishCase: @escaping () -> Void
    ) {
        self.roleName = roleName
        self.caseEntity = caseEntity
        self.recordTranscript = recordTranscript
        self.gptWitnessAnswer = gptWitnessAnswer
        self.onFinishCase = onFinishCase

        let req = NSFetchRequest<Conversation>(entityName: "Conversation")
        req.predicate = NSPredicate(
            format: "caseEntity == %@ AND phase == %@",
            caseEntity,
            CasePhase.trial.rawValue
        )
        req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        _messages = FetchRequest(fetchRequest: req)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(roleName)
                .font(.headline)

            if awaitingUser {
                // The AI's question
                Text(pendingQuestion)
                    .padding()
                    .multilineTextAlignment(.center)

                // Inline bar with Object / Proceed
                HStack {
                    Button("Object") {
                        showObjectionInput = true
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Proceed") {
                        allowAnswer()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

            } else if isLoading {
                ProgressView().padding()
            } else if currentWitness == nil {
                Text("\(roleName) finished questioning.")
                Button("Continue", action: onFinishCase)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Proceed", action: askQuestion)
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
            }
        }
        .padding()
        .onAppear(perform: nextWitness)

        // Objection entry sheet
        .sheet(isPresented: $showObjectionInput) {
            NavigationView {
                Form {
                    Section("Your Objection") {
                        TextField("Why do you object?", text: $objectionText)
                    }
                }
                .navigationTitle("Objection")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            objectionText = ""
                            showObjectionInput = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") {
                            submitObjection()
                        }
                        .disabled(objectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func askQuestion() {
        guard let w = currentWitness else { return }
        if askedQuestions.count >= questionLimit {
            // Move to next witness or finish case
            if let nextWitness = getNextWitness() {
                currentWitness = nextWitness
                contextSummary = ""
                askedQuestions = []
                recordTranscript(roleName, "I'll now call \(nextWitness.name ?? "the next witness").")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    askQuestion()
                }
            } else {
                recordTranscript(roleName, "I rest my case.")
                onFinishCase()
            }
            return
        }
        isLoading = true
        let systemPrompt = """
        You are \(roleName). \
        Ask ONE concise question of \(w.name ?? "the witness") based on context.
        You have asked \(askedQuestions.count) of \(questionLimit) questions.
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
                    if clean.isEmpty || askedQuestions.contains(clean) {
                        if let nextWitness = getNextWitness() {
                            currentWitness = nextWitness
                            contextSummary = ""
                            askedQuestions = []
                            recordTranscript(roleName, "I'll now call \(nextWitness.name ?? "the next witness").")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                askQuestion()
                            }
                        } else {
                            recordTranscript(roleName, "I rest my case.")
                            onFinishCase()
                        }
                    } else {
                        pendingQuestion = clean
                        awaitingUser = true
                    }
                case .failure:
                    recordTranscript("Judge", "Please proceed.")
                    onFinishCase()
                }
            }
        }
    }

    private func getNextWitness() -> CourtCharacter? {
        let all = (caseEntity.witnesses as? Set<CourtCharacter> ?? [])
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
        if let current = currentWitness,
           let idx = all.firstIndex(of: current),
           idx + 1 < all.count {
            return all[idx + 1]
        }
        return nil
    }

    private func allowAnswer() {
        guard let w = currentWitness else { return }
        recordTranscript(roleName, pendingQuestion)
        awaitingUser = false
        askedQuestions.append(pendingQuestion)
        gptWitnessAnswer(w.name ?? "", pendingQuestion, contextSummary) { ans in
            recordTranscript(w.name ?? "", ans)
            contextSummary += "Q: \(pendingQuestion)\nA: \(ans)\n"
            askQuestion()
        }
    }

    private func submitObjection() {
        showObjectionInput = false
        recordTranscript(roleName, "Objection: \(objectionText)")
        isLoading = true
        let judgePrompt = """
        You are the judge. Counsel objected: \
        \(objectionText). Based on context: \(contextSummary), rule:
        """
        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: judgePrompt,
            user: ""
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                let ruling: String
                if case .success(let r) = result {
                    ruling = r.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    ruling = "Overruled."
                }
                recordTranscript("Judge", ruling)
                if ruling.lowercased().contains("sustain") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        askQuestion()
                    }
                } else {
                    allowAnswer()
                }
                objectionText = ""
            }
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
