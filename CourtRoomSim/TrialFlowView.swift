// TrialFlowView.swift
// CourtRoomSim

import SwiftUI
import CoreData

/// High‑level trial stages.
enum TrialStage: String {
    case openingStatements
    case prosecutionCase
    case defenseCase
    case closingArguments
    case juryDeliberation
    case verdict
}

/// Fallback personalities for jurors.
let jurorFallbackPersonalities = [
    "Analytical", "Empathetic", "Skeptical", "Impulsive",
    "Detail‑oriented", "Pragmatic", "Cautious", "Idealistic",
    "Gruff‑but‑fair", "Stubborn", "Methodical", "Warm‑hearted"
]

struct TrialFlowView: View {
    // MARK: – Dependencies
    @ObservedObject var caseEntity: CaseEntity
    @Environment(\.managedObjectContext) var viewContext

    @FetchRequest private var trialEvents: FetchedResults<TrialEvent>

    // MARK: – UI State (made internal so Helpers file can access)
    @State var currentStage: TrialStage = .openingStatements
    @State var currentSpeaker: String = "Prosecution"
    @State var isLoading: Bool = false
    @State var showRoster: Bool = false
    @State var errorMessage: String?

    init(caseEntity: CaseEntity) {
        self.caseEntity = caseEntity
        // Fetch all TrialEvent for this case
        let req = NSFetchRequest<TrialEvent>(entityName: "TrialEvent")
        req.predicate = NSPredicate(format: "caseEntity == %@", caseEntity)
        req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        _trialEvents = FetchRequest(fetchRequest: req)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack {
                Spacer()
                Button("Case Roster") { showRoster = true }
                    .padding(.trailing, 16)
            }
            .padding(.top, 4)

            Divider()

            // Transcript scroll
            TrialTranscriptView(events: trialEvents)

            if let err = errorMessage {
                Text(err)
                    .foregroundColor(.red)
                    .padding(.vertical, 2)
            }
            if isLoading {
                ProgressView().padding(.vertical, 2)
            }

            Divider()

            // Stage dispatch
            switch currentStage {
            case .openingStatements:
                OpeningStatementsView(
                    caseEntity: caseEntity,
                    currentSpeaker: $currentSpeaker,
                    record: recordEvent,
                    autoOpponent: gptOpponentStatement,
                    moveNext: advanceStage
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
                        finishCase: advanceStage
                    )
                } else {
                    AiCounselView(
                        roleName: "Prosecution (AI)",
                        caseEntity: caseEntity,
                        recordTranscript: recordEvent,
                        gptWitnessAnswer: gptWitnessAnswer,
                        onFinishCase: advanceStage
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
                        finishCase: advanceStage
                    )
                } else {
                    AiCounselView(
                        roleName: "Defense (AI)",
                        caseEntity: caseEntity,
                        recordTranscript: recordEvent,
                        gptWitnessAnswer: gptWitnessAnswer,
                        onFinishCase: advanceStage
                    )
                }

            case .closingArguments:
                ClosingArgumentsView(
                    caseEntity: caseEntity,
                    currentSpeaker: $currentSpeaker,
                    record: recordEvent,
                    autoOpponent: gptOpponentStatement,
                    moveNext: advanceStage
                )

            case .juryDeliberation:
                JuryDeliberationView(
                    caseEntity: caseEntity,
                    recordTranscript: recordEvent,
                    finalizeVerdict: setVerdict
                )

            case .verdict:
                VStack {
                    Text("Verdict:")
                        .font(.headline)
                    Text(caseEntity.verdict ?? "Undecided")
                        .font(.title)
                        .padding(.top, 4)
                }
                .padding()
            }
        }
        .navigationTitle("Trial")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRoster) {
            CaseRosterSheet(caseEntity: caseEntity)
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear { ensureJudgeAndJury() }
    }

    // MARK: – Helpers (made internal so Helpers file can call them)

    /// True if the user is filling the prosecutor role.
    var isUserProsecutor: Bool {
        (caseEntity.userRole ?? "")
            .lowercased().contains("prosecutor")
    }

    /// Persist a trial event.
    func recordEvent(_ speaker: String, _ msg: String) {
        let ev = TrialEvent(context: viewContext)
        ev.id = UUID()
        ev.speaker = speaker
        ev.message = msg
        ev.timestamp = Date()
        ev.caseEntity = caseEntity
        try? viewContext.save()
    }

    /// Advance to the next trial stage.
    func advanceStage() {
        currentStage = {
            switch currentStage {
            case .openingStatements:   return .prosecutionCase
            case .prosecutionCase:     return .defenseCase
            case .defenseCase:         return .closingArguments
            case .closingArguments:    return .juryDeliberation
            case .juryDeliberation:    return .verdict
            case .verdict:             return .verdict
            }
        }()
    }

    /// Capture and save the final verdict.
    func setVerdict(_ verdict: String) {
        caseEntity.verdict = verdict
        try? viewContext.save()
        currentStage = .verdict
    }

    /// Ensure judge and 12 jurors exist before trial.
    func ensureJudgeAndJury() {
        if caseEntity.judge == nil {
            let judge = CourtCharacter(context: viewContext)
            judge.id = UUID()
            judge.name = "Judge " + ["Summerton","Hawkins","Delgado","Price"]
                .randomElement()!
            judge.personality = ["Fair‑minded","Strict","Patient"]
                .randomElement()!
            judge.background = "Seasoned jurist respected for balanced rulings."
            caseEntity.judge = judge
        }

        let existing = caseEntity.jury as? Set<CourtCharacter> ?? []
        if existing.count < 12 {
            for i in existing.count..<12 {
                let juror = CourtCharacter(context: viewContext)
                juror.id = UUID()
                juror.name = "Juror #\(i+1)"
                juror.personality = jurorFallbackPersonalities
                    .randomElement()!
                juror.background = "Citizen with unique life experience."
                caseEntity.addToJury(juror)
            }
        }
        try? viewContext.save()
    }
}
