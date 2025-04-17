//
//  AiCounselView.swift
//  CourtRoomSim
//

import SwiftUI

struct AiCounselView: View {

    // injected
    let roleName: String
    @ObservedObject var caseEntity: CaseEntity
    let recordTranscript: (String,String) -> Void
    let gptWitnessAnswer: (String,String,String,@escaping(String)->Void) -> Void
    let onFinishCase: () -> Void

    // state
    @State private var currentIndex = 0
    @State private var currentWitness: CourtCharacter?
    @State private var context  = ""
    @State private var asked    = [String]()
    @State private var pendingQ = ""
    @State private var awaitingUser = false
    @State private var showObj  = false
    @State private var objReason = ""
    @State private var isLoading = false
    @State private var retries   = 0

    var body: some View {
        VStack(spacing:12) {
            Text(roleName).font(.headline)

            if awaitingUser {
                Text(pendingQ).padding()
                HStack {
                    Button("Object") { showObj = true }
                    Spacer()
                    Button("Allow") { allowAnswer() }
                }
                .padding(.horizontal)

            } else if isLoading {
                ProgressView()

            } else if currentWitness == nil {
                Text("\(roleName) finished.")
                Button("Continue") { onFinishCase() }

            } else {
                Button("AI Ask Question") { askQuestion() }
            }
        }
        .alert("Objection", isPresented: $showObj) {
            TextField("Reason", text: $objReason)
            Button("Submit") { handleObjection() }
            Button("Cancel", role:.cancel) {}
        }
        .padding()
        .onAppear { nextWitness() }
    }

    // MARK: – AI question
    private func askQuestion() {
        guard let w = currentWitness, retries < 3 else { nextWitness(); return }
        isLoading = true

        let system = "Opposing counsel single question."
        let user = """
        You are \(roleName) questioning \(w.name ?? "witness").
        Do NOT repeat questions: \(asked.joined(separator:" | "))
        Context:
        \(context)
        """

        OpenAIHelper.shared.chatCompletion(
            model: AiModel.defaultModel.rawValue,
            system: system,
            user:   user)
        { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .failure: self.retry()
                case .success(let q):
                    let clean = q.trimmingCharacters(in:.whitespacesAndNewlines)
                    if self.asked.contains(where:{
                        $0.caseInsensitiveCompare(clean) == .orderedSame })
                    { self.retry(); return }

                    self.pendingQ     = clean
                    self.asked.append(clean)
                    self.recordTranscript(self.roleName, clean)
                    self.awaitingUser = true
                }
            }
        }
    }

    private func retry() { retries += 1; askQuestion() }

    // MARK: – allow / objection
    private func allowAnswer() {
        awaitingUser = false
        guard let w = currentWitness else { return }
        gptWitnessAnswer(w.name ?? "", pendingQ, context) { ans in
            self.recordTranscript(w.name ?? "", ans)
            self.context += "Q: \(self.pendingQ)\nA: \(ans)\n"
        }
    }

    private func handleObjection() {
        awaitingUser = false
        let sustained = Bool.random()
        recordTranscript(oppositeRole,
                         "\(oppositeRole) objects (\(objReason)).")
        recordTranscript("Judge", sustained ? "Sustained" : "Overruled")
        if !sustained { allowAnswer() }
        objReason = ""
    }

    // MARK: – witness cycle
    private func nextWitness() {
        let list = possibleWitnesses
        guard currentIndex < list.count else { currentWitness = nil; return }

        currentWitness = list[currentIndex]
        context  = ""
        asked    = []
        pendingQ = ""
        retries  = 0
        awaitingUser = false
        recordTranscript(roleName, "Calls \(currentWitness!.name!)")

        currentIndex += 1
    }

    private var possibleWitnesses: [CourtCharacter] {
        var set = Set<CourtCharacter>()
        if let w = caseEntity.witnesses as? Set<CourtCharacter> { set.formUnion(w) }
        if let p = caseEntity.police   as? Set<CourtCharacter> { set.formUnion(p) }
        if let s = caseEntity.suspect  { set.insert(s) }
        if let v = caseEntity.victim,
           caseEntity.crimeType?.lowercased() != "murder" {
            set.insert(v)
        }
        return Array(set)
    }

    private var oppositeRole: String {
        roleName.contains("Prosecution") ? "Defense" : "Prosecution"
    }
}
