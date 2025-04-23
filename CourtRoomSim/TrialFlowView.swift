// TrialFlowView.swift
// CourtRoomSim

import SwiftUI
import CoreData

enum TrialStage: String, CaseIterable {
    case openingStatements
    case prosecutionCase
    case defenseCase
    case closingArguments
    case juryDeliberation
    case verdict
}

let jurorFallbackPersonalities = [
    "Analytical", "Empathetic", "Skeptical", "Impulsive",
    "Detail‑oriented", "Pragmatic", "Cautious", "Idealistic",
    "Gruff‑but‑fair", "Stubborn", "Methodical", "Warm‑hearted"
]

struct TrialFlowView: View {
    @ObservedObject var caseEntity: CaseEntity
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss
    @FetchRequest var trialEvents: FetchedResults<TrialEvent>
    @State var currentStage: TrialStage
    @State private var currentSpeaker: String = "Prosecution"
    @State var isLoading: Bool = false
    @State private var showRoster: Bool = false
    @State var errorMessage: String? = nil
    @State var isBuildingPlan: Bool = false
    @State private var planOverlayText: String = "Opposing Counsel building their case…"
    @State private var showNotebook: Bool = false

    init(caseEntity: CaseEntity) {
        self.caseEntity = caseEntity
        let rawStage = caseEntity.trialStage ?? TrialStage.openingStatements.rawValue
        _currentStage = State(initialValue: TrialStage(rawValue: rawStage) ?? .openingStatements)
        let request = NSFetchRequest<TrialEvent>(entityName: "TrialEvent")
        request.predicate = NSPredicate(format: "caseEntity == %@", caseEntity)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        _trialEvents = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Divider()
                ZStack {
                    VStack(spacing: 0) {
                        TrialTranscriptView(events: trialEvents)
                        if let err = errorMessage {
                            Text(err)
                                .foregroundColor(.red)
                                .padding(.vertical, 2)
                        }
                        if isLoading {
                            ProgressView()
                                .padding(.vertical, 2)
                        }
                        Divider()
                        switch currentStage {
                        case .openingStatements:
                            OpeningStatementsView(
                                caseEntity: caseEntity,
                                currentSpeaker: $currentSpeaker,
                                record: recordEvent,
                                autoOpponent: gptOpponentStatement,
                                moveNext: advanceStageAndPersist
                            )
                        case .prosecutionCase:
                            if isUserProsecutor {
                                DirectExaminationView(
                                    roleName: "Prosecution",
                                    caseEntity: caseEntity,
                                    record: recordEvent,
                                    gptAnswer: gptWitnessAnswer,
                                    gptCross: gptOpponentCrossExam,
                                    isLoading: $isLoading,
                                    lockWitness: true,
                                    finishCase: advanceStageAndPersist,
                                    onPlanUpdate: buildPlan
                                )
                            } else {
                                DirectExaminationView(
                                    roleName: "Prosecution (AI)",
                                    caseEntity: caseEntity,
                                    record: recordEvent,
                                    gptAnswer: gptWitnessAnswer,
                                    gptCross: gptOpponentCrossExam,
                                    isLoading: $isLoading,
                                    lockWitness: true,
                                    finishCase: advanceStageAndPersist,
                                    onPlanUpdate: buildPlan
                                )
                            }
                        case .defenseCase:
                            if !isUserProsecutor {
                                DirectExaminationView(
                                    roleName: "Defense",
                                    caseEntity: caseEntity,
                                    record: recordEvent,
                                    gptAnswer: gptWitnessAnswer,
                                    gptCross: gptOpponentCrossExam,
                                    isLoading: $isLoading,
                                    lockWitness: true,
                                    finishCase: advanceStageAndPersist,
                                    onPlanUpdate: buildPlan
                                )
                            } else {
                                DirectExaminationView(
                                    roleName: "Defense (AI)",
                                    caseEntity: caseEntity,
                                    record: recordEvent,
                                    gptAnswer: gptWitnessAnswer,
                                    gptCross: gptOpponentCrossExam,
                                    isLoading: $isLoading,
                                    lockWitness: true,
                                    finishCase: advanceStageAndPersist,
                                    onPlanUpdate: buildPlan
                                )
                            }
                        case .closingArguments:
                            ClosingArgumentsView(
                                caseEntity: caseEntity,
                                currentSpeaker: $currentSpeaker,
                                record: recordEvent,
                                autoOpponent: gptOpponentStatement,
                                moveNext: advanceStageAndPersist
                            )
                        case .juryDeliberation:
                            JuryDeliberationView(
                                caseEntity: caseEntity,
                                recordTranscript: recordEvent,
                                finalizeVerdict: { verdict in
                                    setVerdict(verdict)
                                    persistStage(.verdict)
                                }
                            )
                        case .verdict:
                            VStack(spacing: 16) {
                                Text("Verdict: \(caseEntity.verdict ?? "Undecided")")
                                    .font(.largeTitle)
                                    .bold()
                                Button("Close Case") { dismiss() }
                                    .padding()
                            }
                        }
                    }

                    if isBuildingPlan {
                        Color(.systemBackground)
                            .opacity(0.8)
                            .edgesIgnoringSafeArea(.all)
                        VStack(spacing: 16) {
                            ProgressView()
                            Text(planOverlayText)
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("Trial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Case Roster") { showRoster = true }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNotebook = true }) {
                        Image(systemName: "book")
                            .imageScale(.large)
                            .accessibilityLabel("Notebook")
                    }
                }
            }
            .sheet(isPresented: $showRoster) {
                CaseRosterSheet(caseEntity: caseEntity)
                    .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $showNotebook) {
                NotebookView(caseEntity: caseEntity)
                    .environment(\.managedObjectContext, viewContext)
            }
            .onAppear {
                ensureJudgeAndJury()
                persistStage(currentStage)
                buildPlan()
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
    }

    // MARK: – Helpers

    var isUserProsecutor: Bool {
        (caseEntity.userRole ?? "").lowercased().contains("prosecutor")
    }

    func recordEvent(_ speaker: String, _ msg: String) {
        let ev = TrialEvent(context: viewContext)
        ev.id = UUID()
        ev.speaker = speaker
        ev.message = msg
        ev.timestamp = Date()
        ev.caseEntity = caseEntity
        try? viewContext.save()
    }

    func advanceStageAndPersist() {
        switch currentStage {
        case .openingStatements: currentStage = .prosecutionCase
        case .prosecutionCase: currentStage = .defenseCase
        case .defenseCase: currentStage = .closingArguments
        case .closingArguments: currentStage = .juryDeliberation
        case .juryDeliberation: currentStage = .verdict
        case .verdict: break
        }
        persistStage(currentStage)
    }

    func persistStage(_ stage: TrialStage) {
        caseEntity.trialStage = stage.rawValue
        // Map trial stage to high-level case phase
        switch stage {
        case .openingStatements, .prosecutionCase, .defenseCase, .closingArguments:
            caseEntity.phase = CasePhase.trial.rawValue
        case .juryDeliberation:
            caseEntity.phase = CasePhase.juryDeliberation.rawValue
        case .verdict:
            caseEntity.phase = CasePhase.completed.rawValue
        }
        try? viewContext.save()
    }

    func setVerdict(_ verdict: String) {
        caseEntity.verdict = verdict
        try? viewContext.save()
        currentStage = .verdict
    }

    private func ensureJudgeAndJury() {
        if caseEntity.judge == nil {
            let judge = CourtCharacter(context: viewContext)
            judge.id = UUID()
            judge.name = "Judge " + ["Summerton","Hawkins","Delgado","Price"].randomElement()!
            judge.personality = ["Fair‑minded","Strict","Patient"].randomElement()!
            judge.background = "Seasoned jurist respected for balanced rulings."
            caseEntity.judge = judge
        }
        let existing = caseEntity.jury as? Set<CourtCharacter> ?? []
        if existing.count < 12 {
            for i in existing.count..<12 {
                let juror = CourtCharacter(context: viewContext)
                juror.id = UUID()
                juror.name = "Juror #\(i+1)"
                juror.personality = jurorFallbackPersonalities.randomElement()!
                juror.background = "Citizen with unique life experience."
                caseEntity.addToJury(juror)
            }
        }
        try? viewContext.save()
    }

    func buildPlan() {
        guard let opp = caseEntity.opposingCounsel else { return }
        let existingPlan = (try? viewContext.fetch(
            NSFetchRequest<AIPlan>(entityName: "AIPlan")
        ))?.first
        planOverlayText = existingPlan == nil
            ? "Opposing Counsel building their case…"
            : "Opposing Counsel updating their case…"
        isBuildingPlan = true

        let convFetch: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        convFetch.predicate = NSPredicate(
            format: "caseEntity == %@ AND phase == %@",
            caseEntity, CasePhase.preTrial.rawValue
        )
        convFetch.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        let preHistory = (try? viewContext.fetch(convFetch))?
            .map { "\($0.sender ?? ""): \($0.message ?? "")" }
            .joined(separator: "\n") ?? ""
        let evidence = caseEntity.details ?? ""
        let planText = existingPlan?.planText ?? ""
        let systemPrompt = """
 You are \(opp.name ?? "Opposing Counsel"), the \
 \(isUserProsecutor ? "Defense Counsel" : "Prosecuting Counsel") in a US criminal court.
 Based on evidence: \(evidence),
 prior transcript: \(preHistory),
 and existing plan: \(planText),
 update your concise strategic plan.
 """
        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: "Please generate or update your case plan now."
        ) { result in
            DispatchQueue.main.async {
                isBuildingPlan = false
                switch result {
                case .success(let text):
                    let planEnt = existingPlan ?? AIPlan(context: viewContext)
                    planEnt.id = planEnt.id ?? UUID()
                    planEnt.planText = text
                    planEnt.lastUpdated = Date()
                    planEnt.caseEntity = caseEntity
                    try? viewContext.save()
                case .failure(let err):
                    errorMessage = err.localizedDescription
                }
            }
        }
    }

    // MARK: – AI Opponent Statement

    func gptOpponentStatement(userText: String) {
        guard let opp = caseEntity.opposingCounsel else { return }
        let apiKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        guard !apiKey.isEmpty else { return }

        isLoading = true

        // Full trial transcript
        let transcript = trialEvents
            .map { "\($0.speaker): \($0.message)" }
            .joined(separator: "\n")

        // Latest AI plan
        let planFetch: NSFetchRequest<AIPlan> = AIPlan.fetchRequest()
        planFetch.predicate = NSPredicate(format: "caseEntity == %@", caseEntity)
        let planText = (try? viewContext.fetch(planFetch))?.first?.planText ?? ""

        let systemPrompt = """
        You are \(opp.name ?? "Opposing Counsel"), the \
        \(isUserProsecutor ? "Defense Counsel" : "Prosecuting Counsel") in a US criminal court.
        Case summary: \(caseEntity.details ?? "")
        AI plan so far: \(planText)
        Trial transcript so far:
        \(transcript)
        Respond exactly once (≤2 sentences), then say "I rest my case."
        """
        let userPrompt = "Opponent statement request after: \"\(userText)\""

        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: userPrompt
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let reply):
                    recordEvent(opp.name ?? "Opposing Counsel", reply)
                    // Only advance stage if the AI has finished their statement
                    if reply.lowercased().contains("i rest my case") {
                        advanceStageAndPersist()
                    }
                case .failure(let err):
                    errorMessage = err.localizedDescription
                }
            }
        }
    }

    // MARK: – AI Witness Answer

    func gptWitnessAnswer(
        _ witnessName: String,
        _ _question: String,
        _ context: String,
        _ onReply: @escaping (String) -> Void
    ) {
        let apiKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        guard !apiKey.isEmpty else {
            onReply("No API key"); return
        }

        isLoading = true

        // Identify the character entity for additional context
        let allChars = ([caseEntity.victim] +
                        (caseEntity.witnesses as? [CourtCharacter] ?? []) +
                        (caseEntity.police as? [CourtCharacter] ?? []) +
                        [caseEntity.suspect, caseEntity.opposingCounsel]).compactMap { $0 }
        let charEnt = allChars.first(where: { $0.name == witnessName })

        let personality = charEnt?.personality ?? ""
        let background  = charEnt?.background  ?? ""
        let roleDesc    = charEnt?.role        ?? ""

        // Pre‑trial conversation
        let convFetch: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        convFetch.predicate = NSPredicate(
            format: "caseEntity == %@ AND phase == %@",
            caseEntity, CasePhase.preTrial.rawValue
        )
        convFetch.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        let preHistory = (try? viewContext.fetch(convFetch))?
            .map { "\($0.sender ?? ""): \($0.message ?? "")" }
            .joined(separator: "\n") ?? ""

        // Trial transcript
        let transcript = trialEvents
            .map { "\($0.speaker): \($0.message)" }
            .joined(separator: "\n")

        let systemPrompt = """
        You are \(witnessName), \(roleDesc). Personality: \(personality). Background: \(background).
        Case summary: \(caseEntity.details ?? "")
        Pre‑trial conversation:
        \(preHistory)
        Trial transcript so far:
        \(transcript)
        Answer the question in first person, fully addressing it.
        """

        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: _question
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let text): onReply(text)
                case .failure:          onReply("…")
                }
            }
        }
    }

    // MARK: – AI Opponent Cross‑Exam

    func gptOpponentCrossExam(
        _ witness: String,
        _ _context: String,
        _ askedSoFar: [String],
        _ onNewQuestion: @escaping (String?) -> Void
    ) {
        guard let opp = caseEntity.opposingCounsel else {
            onNewQuestion(nil); return
        }
        let apiKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        guard !apiKey.isEmpty else {
            onNewQuestion(nil); return
        }

        isLoading = true

        // Get full trial context
        let transcript = trialEvents
            .map { "\($0.speaker): \($0.message)" }
            .joined(separator: "\n")
            
        // Get AI plan
        let planFetch: NSFetchRequest<AIPlan> = AIPlan.fetchRequest()
        planFetch.predicate = NSPredicate(format: "caseEntity == %@", caseEntity)
        let planText = (try? viewContext.fetch(planFetch))?.first?.planText ?? ""
        
        // Get witness profile
        let allChars = ([caseEntity.victim] +
                        (caseEntity.witnesses as? [CourtCharacter] ?? []) +
                        (caseEntity.police as? [CourtCharacter] ?? []) +
                        [caseEntity.suspect]).compactMap { $0 }
        let charEnt = allChars.first(where: { $0.name == witness })
        
        let personality = charEnt?.personality ?? ""
        let background = charEnt?.background ?? ""
        let roleDesc = charEnt?.role ?? ""
        
        let aiRole = isUserProsecutor ? "Defense Counsel" : "Prosecuting Counsel"
        let oppName = opp.name ?? "Opposing Counsel"
        let oppRole = opp.role ?? aiRole

        let systemPrompt = """
        You are \(oppName), the \(oppRole).
        Case summary: \(caseEntity.details ?? "")
        AI plan: \(planText)
        
        Trial transcript so far:
        \(transcript)
        
        You are cross-examining \(witness), \(roleDesc).
        Witness personality: \(personality)
        Witness background: \(background)
        
        Already asked: \(askedSoFar.joined(separator: " | "))
        
        Ask ONE concise cross-examination question that advances your case strategy.
        Focus on challenging the witness's credibility or testimony.
        If you have no further questions, respond with exactly: "No further questions, your honor."
        """

        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: ""
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let text):
                    let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if clean.lowercased() == "no further questions, your honor." {
                        onNewQuestion(nil)
                    } else {
                        onNewQuestion(clean)
                    }
                case .failure:
                    onNewQuestion(nil)
                }
            }
        }
    }
}
