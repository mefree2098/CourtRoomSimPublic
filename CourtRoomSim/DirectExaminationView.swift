// CourtRoomSim/Views/DirectExaminationView.swift

import SwiftUI
import CoreData
import os

private let directLogger = Logger(subsystem: "com.pura.CourtRoomSim", category: "DirectExaminationView")

struct DirectExaminationView: View {
    // MARK: – Dependencies
    let roleName: String
    @ObservedObject var caseEntity: CaseEntity
    let record: (String, String) -> Void
    let gptAnswer: (_ witness: String,
                    _ question: String,
                    _ context: String,
                    _ callback: @escaping (String) -> Void) -> Void
    let gptCross: (_ witness: String,
                   _ context: String,
                   _ asked: [String],
                   _ callback: @escaping (String?) -> Void) -> Void
    @Binding var isLoading: Bool
    let lockWitness: Bool
    let finishCase: () -> Void
    let onPlanUpdate: () -> Void
    
    // MARK: – Environment
    @Environment(\.managedObjectContext) var viewContext
    @FetchRequest private var trialEvents: FetchedResults<TrialEvent>

    // MARK: – UI State
    @State private var selected: CourtCharacter?
    @State private var questionText = ""
    @State private var directSummary = ""
    @State private var step = 0             // 0=direct, 1=cross, 2=redirect, 3=done
    @State private var askedCross: [String] = []
    @State private var askedFirst = false
    @State private var pendingCrossQuestion: String? = nil
    @State private var isAiCase = false     // New state to track if we're in AI's case
    @State private var aiQuestionCount = 0  // Track AI's question count per witness
    @State private var aiWitnessIndex = 0   // Track which witness AI is currently questioning
    @State private var aiWitnesses: [CourtCharacter] = [] // List of witnesses for AI to call
    @State private var aiRedirecting = false // Track if AI is redirecting
    @State private var questionedWitnesses: Set<CourtCharacter> = [] // Track which witnesses have been questioned

    // Manual objection sheet
    @State private var showObjectionInput = false
    @State private var objectionText = ""

    // Limit cross‑exam questions
    private let crossQuestionLimit = 5

    init(
        roleName: String,
        caseEntity: CaseEntity,
        record: @escaping (String, String) -> Void,
        gptAnswer: @escaping (_ witness: String,
                             _ question: String,
                             _ context: String,
                             _ callback: @escaping (String) -> Void) -> Void,
        gptCross: @escaping (_ witness: String,
                            _ context: String,
                            _ asked: [String],
                            _ callback: @escaping (String?) -> Void) -> Void,
        isLoading: Binding<Bool>,
        lockWitness: Bool,
        finishCase: @escaping () -> Void,
        onPlanUpdate: @escaping () -> Void
    ) {
        self.roleName = roleName
        self.caseEntity = caseEntity
        self.record = record
        self.gptAnswer = gptAnswer
        self.gptCross = gptCross
        self._isLoading = isLoading
        self.lockWitness = lockWitness
        self.finishCase = finishCase
        self.onPlanUpdate = onPlanUpdate
        
        // Initialize FetchRequest for trial events
        let request = NSFetchRequest<TrialEvent>(entityName: "TrialEvent")
        request.predicate = NSPredicate(format: "caseEntity == %@", caseEntity)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        self._trialEvents = FetchRequest(fetchRequest: request)
        
        // Set isAiCase based on role name
        self._isAiCase = State(initialValue: roleName.contains("(AI)"))
        
        // Initialize AI witnesses if this is AI's case
        if roleName.contains("(AI)") {
            let witnesses = possibleWitnesses
            self._aiWitnesses = State(initialValue: witnesses)
            self._aiWitnessIndex = State(initialValue: 0)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("\(roleName) Case")
                .font(.headline)

            // Witness picker
            Group {
                if askedFirst && lockWitness {
                    Text(selected?.name ?? "")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                } else if !isAiCase {
                    Picker("Witness", selection: $selected) {
                        Text("None").tag(CourtCharacter?.none)
                        ForEach(possibleWitnesses, id: \.id) { w in
                            HStack {
                                Text(w.name ?? "Witness")
                                if questionedWitnesses.contains(w) {
                                    Text("(✓)")
                                        .foregroundColor(.gray)
                                }
                            }.tag(CourtCharacter?.some(w))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }

            Divider()

            // Direct / cross / redirect UI…
            if step == 0 {
                if isAiCase {
                    // Show AI's direct examination
                    if let q = pendingCrossQuestion {
                        Text(q)
                            .padding()
                            .multilineTextAlignment(.center)

                        HStack {
                            Button("Object") { showObjectionInput = true }
                                .buttonStyle(.bordered)
                            Spacer()
                            Button("Proceed") { proceedAiQuestion() }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.horizontal)
                    } else if selected == nil {
                        // AI needs to select a witness
                        Button("Call Next Witness", action: selectNextAiWitness)
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading || aiWitnessIndex >= aiWitnesses.count)
                    } else {
                        // AI is ready to ask a question
                        Button("Ask Question", action: askAiQuestion)
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading)
                    }
                } else {
                    // User's direct examination
                    HStack {
                        TextField("Ask a question…", text: $questionText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Ask") { ask() }
                            .disabled(selected == nil || questionText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal)

                    // Always show Done with Direct button during direct examination
                    Button("Done with Direct") {
                        finishDirect()
                    }
                    .disabled(selected == nil)
                    .padding(.horizontal)
                }
            }
            else if let q = pendingCrossQuestion {
                Text(q)
                    .padding()
                    .multilineTextAlignment(.center)

                HStack {
                    Button("Object") { showObjectionInput = true }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Proceed") { proceedCross() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
            else if step == 1 {
                if isAiCase {
                    // AI deciding whether to redirect
                    Button("Proceed to Re-Direct") { 
                        aiRedirecting = true
                        step = 2 
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                    .padding(.horizontal)
                } else {
                    Button("Proceed to Re-Direct") { step = 2 }
                        .disabled(isLoading)
                        .padding(.horizontal)
                }
            }
            else if step == 2 {
                HStack {
                    TextField("Ask re-direct question…", text: $questionText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Ask") { askRedirect() }
                        .disabled(questionText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)
                Button("No More Questions") { finishRedirect() }
                    .padding(.horizontal)
            }
            else {
                Button("Finish with this Witness") { nextWitness() }
                    .padding(.horizontal)
            }

            Divider()

            // Only show Finish Entire Case button for user's case
            if !isAiCase {
                Button("Finish Entire \(roleName) Case") { finishCase() }
                    .padding(.top, 4)
            }
        }
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
                        Button("Submit") { submitObjection() }
                            .disabled(objectionText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            if isAiCase && selected == nil {
                selectNextAiWitness()
            }
        }
    }

    // MARK: – Actions

    private func selectNextAiWitness() {
        guard aiWitnessIndex < aiWitnesses.count else { 
            directLogger.debug("No more witnesses to call, resting case")
            record(roleName, "I rest my case.")
            finishCase()
            return 
        }
        
        selected = aiWitnesses[aiWitnessIndex]
        askedFirst = true
        aiQuestionCount = 0
        directSummary = ""
        directLogger.debug("Calling witness: \(selected?.name ?? "unknown"), index: \(aiWitnessIndex)")
        record(roleName, "I call \(selected?.name ?? "the witness") to the stand.")
        
        // Ask first question immediately
        askAiQuestion()
    }

    private func askAiQuestion() {
        guard let w = selected, let name = w.name else { 
            directLogger.debug("No witness selected, cannot ask question")
            return 
        }
        
        directLogger.debug("Asking question \(aiQuestionCount + 1) of 5 to witness: \(name)")
        
        if aiQuestionCount >= 5 {
            // Move to next witness or finish case
            if aiWitnessIndex + 1 < aiWitnesses.count {
                aiWitnessIndex += 1
                selected = nil
                directLogger.debug("Finished with witness \(name), moving to next witness")
                record(roleName, "No further questions, your honor.")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    selectNextAiWitness()
                }
            } else {
                directLogger.debug("Finished with last witness \(name), resting case")
                record(roleName, "No further questions, your honor.")
                record(roleName, "I rest my case.")
                finishCase()
            }
            return
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
        let personality = w.personality ?? ""
        let background = w.background ?? ""
        let roleDesc = w.role ?? ""
        
        let systemPrompt = """
        You are \(roleName). You are questioning \(name), \(roleDesc).
        Witness personality: \(personality)
        Witness background: \(background)
        
        Case summary: \(caseEntity.details ?? "")
        AI plan: \(planText)
        
        Trial transcript so far:
        \(transcript)
        
        You have asked \(aiQuestionCount) of 5 questions to this witness.
        Ask ONE concise, relevant question that advances your case strategy.
        """
        
        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: "Please ask a question to advance your case strategy."
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let q):
                    let clean = q.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        directLogger.debug("Generated question for \(name): \(clean)")
                        pendingCrossQuestion = clean
                    } else {
                        directLogger.debug("Failed to generate question for \(name), moving to next witness")
                        // If AI couldn't generate a question, move to next witness
                        if aiWitnessIndex + 1 < aiWitnesses.count {
                            aiWitnessIndex += 1
                            selected = nil
                            record(roleName, "No further questions, your honor.")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                selectNextAiWitness()
                            }
                        } else {
                            record(roleName, "No further questions, your honor.")
                            record(roleName, "I rest my case.")
                            finishCase()
                        }
                    }
                case .failure(let err):
                    directLogger.error("Error generating question: \(err.localizedDescription)")
                    record(roleName, "No further questions, your honor.")
                    record(roleName, "I rest my case.")
                    finishCase()
                }
            }
        }
    }

    private func proceedAiQuestion() {
        guard let q = pendingCrossQuestion, let name = selected?.name else { 
            directLogger.debug("Cannot proceed with question: no question or witness")
            return 
        }
        
        directLogger.debug("Proceeding with question for \(name): \(q)")
        record(roleName, q)
        pendingCrossQuestion = nil
        aiQuestionCount += 1
        
        // Get full trial context for witness answer
        let transcript = trialEvents
            .map { "\($0.speaker): \($0.message)" }
            .joined(separator: "\n")
            
        // Get witness profile
        let personality = selected?.personality ?? ""
        let background = selected?.background ?? ""
        let roleDesc = selected?.role ?? ""
        
        let systemPrompt = """
        You are \(name), \(roleDesc).
        Personality: \(personality)
        Background: \(background)
        
        Case summary: \(caseEntity.details ?? "")
        
        Trial transcript so far:
        \(transcript)
        
        Answer the question in first person, fully addressing it.
        """
        
        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: q
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ans):
                    directLogger.debug("Witness \(name) answered: \(ans)")
                    record(name, ans)
                    directSummary += "Q: \(q)\nA: \(ans)\n"
                    
                    // Ask next question immediately
                    askAiQuestion()
                case .failure(let err):
                    directLogger.error("Error getting witness answer: \(err.localizedDescription)")
                    record(name, "I decline to answer.")
                    askAiQuestion()
                }
            }
        }
    }

    private func ask() {
        guard let w = selected, let name = w.name else { return }
        let q = questionText.trimmingCharacters(in: .whitespaces)
        askedFirst = true
        step = 0  // Ensure we're in direct examination step
        record(roleName, "Q(\(name)): \(q)")
        questionText = ""
        isLoading = true

        directLogger.debug("Starting objection flow for: \(q, privacy: .public)")

        OpenAIService.shared.requestObjectionResponse(question: q) { objResult in
            DispatchQueue.main.async {
                switch objResult {
                case .success(let obj):
                    directLogger.debug("ObjectionResponse: \(obj.objection), reason: \(obj.reason ?? "nil", privacy: .public)")
                    if obj.objection {
                        record(oppositeRole, "Objection: \(obj.reason ?? "")")
                        directLogger.debug("Recorded objection reason: \(obj.reason ?? "nil", privacy: .public)")
                        OpenAIService.shared.requestJudgeDecision(reason: obj.reason ?? "") { judgeResult in
                            DispatchQueue.main.async {
                                isLoading = false
                                switch judgeResult {
                                case .success(let jd):
                                    directLogger.debug("JudgeDecision: \(jd.decision, privacy: .public)")
                                    if jd.decision.lowercased() == "sustain" {
                                        record("Judge", "Objection sustained.")
                                        // Reset state to allow user to continue questioning
                                        askedFirst = false
                                        step = 0  // Reset to direct examination step
                                    } else {
                                        record("Judge", "Objection overruled.")
                                        performWitnessCall(name: name, question: q)
                                    }
                                case .failure(let err):
                                    directLogger.error("Judge API error: \(err.localizedDescription)")
                                    performWitnessCall(name: name, question: q)
                                }
                            }
                        }
                    } else {
                        directLogger.debug("No objection → calling witness")
                        isLoading = false
                        performWitnessCall(name: name, question: q)
                    }
                case .failure(let err):
                    directLogger.error("Objection API error: \(err.localizedDescription)")
                    isLoading = false
                    performWitnessCall(name: name, question: q)
                }
            }
        }
    }

    private func askRedirect() {
        guard let w = selected, let name = w.name else { return }
        let q = questionText.trimmingCharacters(in: .whitespaces)
        record(roleName, "Q(\(name)): \(q)")
        questionText = ""
        isLoading = true

        directLogger.debug("Starting redirect objection flow for: \(q, privacy: .public)")

        OpenAIService.shared.requestObjectionResponse(question: q) { objResult in
            DispatchQueue.main.async {
                switch objResult {
                case .success(let obj):
                    directLogger.debug("ObjectionResponse: \(obj.objection), reason: \(obj.reason ?? "nil", privacy: .public)")
                    if obj.objection {
                        record(oppositeRole, "Objection: \(obj.reason ?? "")")
                        directLogger.debug("Recorded objection reason: \(obj.reason ?? "nil", privacy: .public)")
                        OpenAIService.shared.requestJudgeDecision(reason: obj.reason ?? "") { judgeResult in
                            DispatchQueue.main.async {
                                isLoading = false
                                switch judgeResult {
                                case .success(let jd):
                                    directLogger.debug("JudgeDecision: \(jd.decision, privacy: .public)")
                                    if jd.decision.lowercased() == "sustain" {
                                        record("Judge", "Objection sustained.")
                                    } else {
                                        performWitnessCall(name: name, question: q)
                                    }
                                case .failure(let err):
                                    directLogger.error("Judge API error: \(err.localizedDescription)")
                                    performWitnessCall(name: name, question: q)
                                }
                            }
                        }
                    } else {
                        directLogger.debug("No objection → calling witness")
                        isLoading = false
                        performWitnessCall(name: name, question: q)
                    }
                case .failure(let err):
                    directLogger.error("Objection API error: \(err.localizedDescription)")
                    isLoading = false
                    performWitnessCall(name: name, question: q)
                }
            }
        }
    }

    private func performWitnessCall(name: String, question: String) {
        gptAnswer(name, question, directSummary) { ans in
            DispatchQueue.main.async {
                record(name, ans)
                directSummary += "Q: \(question)\nA: \(ans)\n"
                isLoading = false
                // Ensure proper state after a successful question
                askedFirst = true
                step = 0  // Reset to direct examination step
            }
        }
    }

    private func finishDirect() {
        if isAiCase {
            // For AI case, move directly to cross-examination
            step = 1
            askCross()
        } else {
            // For user case, record "no further questions" and proceed
            record(roleName, "No further questions, your honor.")
            step = 1
            askedFirst = true
            if let current = selected {
                questionedWitnesses.insert(current)
            }
            askCross()
            onPlanUpdate()
        }
    }

    private func askCross() {
        guard let name = selected?.name else { return }
        if askedCross.count >= crossQuestionLimit {
            record(oppositeRole, "No further questions, your honor.")
            step = 2
            return
        }
        pendingCrossQuestion = nil
        gptCross(name, directSummary, askedCross) { aiQ in
            if let q = aiQ?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
                record(oppositeRole, q)
                pendingCrossQuestion = q
            } else {
                record(oppositeRole, "No further questions, your honor.")
                step = 2
            }
        }
    }

    private func proceedCross() {
        guard let q = pendingCrossQuestion, let name = selected?.name else { return }
        pendingCrossQuestion = nil
        askedCross.append(q)
        gptAnswer(name, q, directSummary) { ans in
            record(name, ans)
            directSummary += "Q: \(q)\nA: \(ans)\n"
            askCross()
        }
    }

    private func finishRedirect() {
        record(roleName, "No further questions, your honor.")
        if let current = selected {
            questionedWitnesses.insert(current)
        }
        nextWitness()
    }

    private func submitObjection() {
        showObjectionInput = false
        
        // Get full trial context for judge decision
        let transcript = trialEvents
            .map { "\($0.speaker): \($0.message)" }
            .joined(separator: "\n")
            
        let systemPrompt = """
        You are the judge in a US criminal court.
        
        Case summary: \(caseEntity.details ?? "")
        
        Trial transcript so far:
        \(transcript)
        
        The \(roleName) has objected to the \(oppositeRole)'s question with the following reason:
        \(objectionText)
        
        Based on US Federal Rules of Evidence (relevance, hearsay, leading, argumentative, speculation),
        decide whether to sustain or overrule the objection.
        Respond with ONLY "Sustained" or "Overruled".
        """
        
        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: ""
        ) { result in
            DispatchQueue.main.async {
                let ruling: String
                if case .success(let r) = result {
                    ruling = r.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    ruling = "Overruled"
                }
                
                // Record in correct order: question -> objection -> ruling -> answer
                if let q = pendingCrossQuestion {
                    record(roleName, "Q(\(selected?.name ?? "")): \(q)")
                }
                record(roleName, "Objection: \(objectionText)")
                record("Judge", "Objection \(ruling.lowercased()).")
                
                if ruling.lowercased() == "sustained" {
                    // If sustained, just clear the pending question and let the user continue
                    pendingCrossQuestion = nil
                    isLoading = false
                } else {
                    // If overruled, proceed with the question
                    proceedAiQuestion()
                }
                
                objectionText = ""
            }
        }
    }

    private func nextWitness() {
        let list = possibleWitnesses
        if let current = selected,
           let idx = list.firstIndex(of: current),
           idx + 1 < list.count {
            selected = list[idx+1]
        } else {
            selected = list.first
        }
        askedFirst = false
        directSummary = ""
        askedCross = []
        step = 0
        onPlanUpdate()
    }

    // MARK: – Helpers

    private var possibleWitnesses: [CourtCharacter] {
        var set = Set<CourtCharacter>()
        if let w = caseEntity.witnesses as? Set<CourtCharacter> { set.formUnion(w) }
        if let p = caseEntity.police    as? Set<CourtCharacter> { set.formUnion(p) }
        if let sus = caseEntity.suspect { set.insert(sus) }
        if let v = caseEntity.victim,
           !(caseEntity.crimeType?.lowercased().contains("murder") ?? false) {
            set.insert(v)
        }
        return Array(set)
    }

    private var oppositeRole: String {
        roleName.lowercased().contains("prosecution") ? "Defense Counsel" : "Prosecutor"
    }
}
