//
//  TrialFlowView.swift
//  CourtRoomSim
//
//  COMPLETE  – 2025‑05‑01
//

import SwiftUI
import CoreData

// MARK: – ENUMS & CONSTANTS
enum TrialStage: String {
    case openingStatements, prosecutionCase, defenseCase,
         closingArguments, juryDeliberation, verdict
}

private let jurorFallbackPersonalities = [
    "Analytical","Empathetic","Skeptical","Impulsive",
    "Detail‑oriented","Pragmatic","Cautious","Idealistic",
    "Gruff‑but‑fair","Stubborn","Methodical","Warm‑hearted"
]

// MARK: – ROOT VIEW
struct TrialFlowView: View {

    // Core‑Data
    @ObservedObject var caseEntity: CaseEntity
    @Environment(\.managedObjectContext) var viewContext

    // Transcript
    @FetchRequest private var trialEvents: FetchedResults<TrialEvent>

    // UI state (internal so helper extension can read/write)
    @State var currentStage:  TrialStage = .openingStatements
    @State var currentSpeaker = "Prosecution"
    @State var isLoading      = false
    @State var showRoster     = false
    @State var errorMessage:  String?

    // ------------------------------------------------------------------
    init(caseEntity: CaseEntity) {
        self.caseEntity = caseEntity
        let req = NSFetchRequest<TrialEvent>(entityName: "TrialEvent")
        req.predicate       = NSPredicate(format: "caseEntity == %@", caseEntity)
        req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        _trialEvents = FetchRequest(fetchRequest: req)
    }

    // MARK: – BODY ------------------------------------------------------
    var body: some View {
        VStack(spacing: 0) {

            // top bar
            HStack {
                Spacer()
                Button("Case Roster") { showRoster = true }
                    .padding(.trailing, 16)
            }
            .padding(.top, 4)

            Divider()

            TrialTranscriptView(events: trialEvents)

            if let err = errorMessage {
                Text(err).foregroundColor(.red).padding(.vertical, 2)
            }
            if isLoading { ProgressView() }

            Divider()

            // stage switcher
            switch currentStage {

            // ───────── OPENING
            case .openingStatements:
                OpeningStatementsView(
                    caseEntity:     caseEntity,
                    currentSpeaker: $currentSpeaker,
                    record:         recordEvent,          // ← fixed label
                    autoOpponent:   gptOpponentStatement,
                    moveNext:       advanceStage)

            // ───────── PROSECUTION CASE
            case .prosecutionCase:
                if isUserProsecutor {
                    DirectExaminationView(
                        roleName:     "Prosecution",
                        caseEntity:   caseEntity,
                        record:       recordEvent,
                        gptAnswer:    gptWitnessAnswer,
                        gptCross:     gptOpponentCrossExam,
                        isLoading:    $isLoading,
                        lockWitness:  true,
                        finishCase:   advanceStage)
                } else {
                    AiCounselView(
                        roleName:           "Prosecution (AI)",
                        caseEntity:         caseEntity,
                        recordTranscript:   recordEvent,
                        gptWitnessAnswer:   gptWitnessAnswer,
                        onFinishCase:       advanceStage)
                }

            // ───────── DEFENSE CASE
            case .defenseCase:
                if !isUserProsecutor {
                    DirectExaminationView(
                        roleName:     "Defense",
                        caseEntity:   caseEntity,
                        record:       recordEvent,
                        gptAnswer:    gptWitnessAnswer,
                        gptCross:     gptOpponentCrossExam,
                        isLoading:    $isLoading,
                        lockWitness:  true,
                        finishCase:   advanceStage)
                } else {
                    AiCounselView(
                        roleName:           "Defense (AI)",
                        caseEntity:         caseEntity,
                        recordTranscript:   recordEvent,
                        gptWitnessAnswer:   gptWitnessAnswer,
                        onFinishCase:       advanceStage)
                }

            // ───────── CLOSING
            case .closingArguments:
                ClosingArgumentsView(
                    caseEntity:     caseEntity,
                    currentSpeaker: $currentSpeaker,
                    record:         recordEvent,
                    autoOpponent:   gptOpponentStatement,
                    moveNext:       advanceStage)

            // ───────── JURY
            case .juryDeliberation:
                JuryDeliberationView(
                    caseEntity:       caseEntity,
                    recordTranscript: recordEvent,
                    finalizeVerdict:  setVerdict)

            // ───────── VERDICT
            case .verdict:
                Text("Verdict: \(caseEntity.verdict ?? "Undecided")")
                    .font(.title)
                    .padding()
            }
        }
        .navigationTitle("Trial")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRoster) { CaseRosterSheet(caseEntity: caseEntity) }
        .onAppear { ensureJudgeAndJury() }
    }

    // MARK: – convenience ----------------------------------------------
    var isUserProsecutor: Bool {
        (caseEntity.userRole ?? "").lowercased().contains("prosecutor")
    }

    func recordEvent(_ speaker: String, _ msg: String) {
        let ev = TrialEvent(context: viewContext)
        ev.id = UUID(); ev.speaker = speaker; ev.message = msg
        ev.timestamp = Date(); ev.caseEntity = caseEntity
        try? viewContext.save()
    }

    func advanceStage() {
        currentStage = switch currentStage {
        case .openingStatements:  .prosecutionCase
        case .prosecutionCase:    .defenseCase
        case .defenseCase:        .closingArguments
        case .closingArguments:   .juryDeliberation
        case .juryDeliberation:   .verdict
        case .verdict:            .verdict
        }
    }

    func setVerdict(_ v: String) {
        caseEntity.verdict = v
        try? viewContext.save()
        currentStage = .verdict
    }

    // ensure judge + jury exist
    func ensureJudgeAndJury() {
        if caseEntity.judge == nil {
            let judge = CourtCharacter(context: viewContext)
            judge.id   = UUID()
            judge.name = "Judge " + ["Summerton","Hawkins","Delgado","Price"].randomElement()!
            judge.personality = ["Fair‑minded","Strict","Patient"].randomElement()!
            judge.background  = "Seasoned jurist respected for balanced rulings."
            caseEntity.judge  = judge
        }

        let existing = caseEntity.jury as? Set<CourtCharacter> ?? []
        if existing.count < 12 {
            (0..<(12 - existing.count)).forEach { _ in
                let juror        = CourtCharacter(context: viewContext)
                juror.id         = UUID()
                juror.name       = "Juror #\(Int.random(in: 100...999))"
                juror.personality = jurorFallbackPersonalities.randomElement()!
                juror.background  = "Citizen with unique life experience."
                caseEntity.addToJury(juror)
            }
        }
        try? viewContext.save()
    }
}
