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

    @FetchRequest
    var trialEvents: FetchedResults<TrialEvent>  // internal access for helpers

    @State var currentStage: TrialStage
    @State private var currentSpeaker: String = "Prosecution"
    @State var isLoading: Bool = false
    @State private var showRoster: Bool = false
    @State var errorMessage: String? = nil
    @State var isBuildingPlan: Bool = false
    @State private var planOverlayText: String = "Opposing Counsel building their case…"

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
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Case Roster") { showRoster = true }
                        .padding(.trailing, 16)
                }
                .padding(.top, 4)

                Divider()

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
                        AiCounselView(
                            roleName: "Prosecution (AI)",
                            caseEntity: caseEntity,
                            recordTranscript: recordEvent,
                            gptWitnessAnswer: gptWitnessAnswer,
                            onFinishCase: advanceStageAndPersist
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
                        AiCounselView(
                            roleName: "Defense (AI)",
                            caseEntity: caseEntity,
                            recordTranscript: recordEvent,    // fixed: use recordEvent instead of trialEvents
                            gptWitnessAnswer: gptWitnessAnswer,
                            onFinishCase: advanceStageAndPersist
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
            .navigationTitle("Trial")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showRoster) {
                CaseRosterSheet(caseEntity: caseEntity)
                    .environment(\.managedObjectContext, viewContext)
            }
            .onAppear {
                ensureJudgeAndJury()
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
        case .prosecutionCase:    currentStage = .defenseCase
        case .defenseCase:        currentStage = .closingArguments
        case .closingArguments:   currentStage = .juryDeliberation
        case .juryDeliberation:   currentStage = .verdict
        case .verdict:            break
        }
        persistStage(currentStage)
    }

    func persistStage(_ stage: TrialStage) {
        caseEntity.trialStage = stage.rawValue
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
}
