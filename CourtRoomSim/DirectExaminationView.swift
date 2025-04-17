import SwiftUI
import CoreData

struct DirectExaminationView: View {

    // MARK: – Dependencies
    let roleName:    String
    @ObservedObject var caseEntity: CaseEntity
    let record:      (String,String) -> Void
    let gptAnswer:   (_ witness:String,_ q:String,_ ctx:String,_ cb:@escaping(String)->Void) -> Void
    let gptCross:    (_ witness:String,_ ctx:String,_ asked:[String],_ cb:@escaping(String?)->Void) -> Void

    @Binding var isLoading: Bool
    let lockWitness:  Bool
    let finishCase:  ()   -> Void

    // MARK: – UI‐state
    @State private var selected:     CourtCharacter?
    @State private var questionText  = ""
    @State private var directSummary = ""
    @State private var step          = 0      // 0‑direct,1‑cross,2‑redirect,3‑done
    @State private var askedCross:   [String] = []
    @State private var askedFirst    = false

    // objection
    @State private var showObj   = false
    @State private var objReason = ""

    // MARK: – Body
    var body: some View {
        VStack(spacing: 10) {
            Text("\(roleName) Case").font(.headline)

            witnessPicker
            questionBar
            objectButton
            phaseButtons

            Divider()
            Button("Finish Entire \(roleName) Case") { finishCase() }
                .padding(.top, 4)
        }
        .alert("State your objection", isPresented: $showObj) {
            TextField("Objection reason", text: $objReason)
            Button("Submit") { submitObjection() }
            Button("Cancel", role: .cancel) { objReason = "" }
        }
        .padding()
    }

    // MARK: – UI components
    private var witnessPicker: some View {
        Group {
            if askedFirst && lockWitness {
                Text(selected?.name ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                Picker("Witness", selection: $selected) {
                    Text("None").tag(CourtCharacter?.none)
                    ForEach(possibleWitnesses, id: \.id) {
                        Text($0.name ?? "Witness")
                            .tag(CourtCharacter?.some($0))
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }

    private var questionBar: some View {
        HStack {
            TextField("Ask a question…", text: $questionText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Ask") { ask() }
                .disabled(selected == nil ||
                          questionText.trimmingCharacters(in:.whitespaces).isEmpty)
        }
        .padding(.horizontal)
    }

    private var objectButton: some View {
        Button("Object (\(oppositeRole))") { showObj = true }
            .disabled(step != 1)
    }

    private var phaseButtons: some View {
        Group {
            if step == 0 {
                Button("Done with Direct") { finishDirect() }
                    .disabled(selected == nil)
            } else if step == 1 {
                Button("Proceed to Re‑Direct") { step = 2 }
            } else if step == 2 {
                Button("Done with Re‑Direct") { finishRedirect() }
            } else if step == 3 {
                Button("Finish with this Witness") { resetWitness() }
            }
        }
    }

    // MARK: – Actions
    private func ask() {
        guard let w = selected, let wName = w.name else { return }
        let q = questionText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }

        askedFirst = true
        record(roleName, "Q(\(wName)): \(q)")
        questionText = ""

        gptAnswer(wName, q, directSummary) { ans in
            record(wName, ans)
            directSummary += "Q: \(q)\nA: \(ans)\n"
        }
    }

    private func finishDirect() {
        step = 1
        guard let w = selected?.name else { return }
        gptCross(w, directSummary, askedCross) { aiQ in
            if let q = aiQ { handleAiCross(q) }
        }
    }

    private func finishRedirect() {
        step = 3
        guard let w = selected?.name else { return }
        gptCross(w, directSummary, askedCross) { aiQ in
            if let q = aiQ { handleAiCross(q) }
        }
    }

    private func submitObjection() {
        let ruling = Bool.random() ? "Sustained" : "Overruled"
        record("Judge", "\(oppositeRole) objects (\(objReason)). Judge: \(ruling)")
        objReason = ""
    }

    private func handleAiCross(_ q: String) {
        record(oppositeRole, q)
        CrossExamUI.shared.present(question: q) { allowed, reason in
            guard let w = selected, let wName = w.name else { return }

            if !allowed {
                let sustained = Bool.random()
                record("Judge",
                       "\(roleName) objects (\(reason)). Judge: \(sustained ? "Sustained" : "Overruled")")
                if sustained { return }
            }
            gptAnswer(wName, q, directSummary) { ans in
                record(wName, ans)
                directSummary += "Q: \(q)\nA: \(ans)\n"
            }
        }
    }

    private func resetWitness() {
        selected       = nil
        askedFirst     = false
        directSummary  = ""
        askedCross     = []
        step = 0
    }

    // MARK: – Helpers
    private var possibleWitnesses: [CourtCharacter] {
        var s = Set<CourtCharacter>()
        if let w = caseEntity.witnesses as? Set<CourtCharacter> { s.formUnion(w) }
        if let p = caseEntity.police   as? Set<CourtCharacter> { s.formUnion(p) }
        if let sus = caseEntity.suspect { s.insert(sus) }
        if let v = caseEntity.victim,
           caseEntity.crimeType?.lowercased() != "murder" { s.insert(v) }
        return Array(s)
    }

    private var oppositeRole: String {
        roleName == "Prosecution" ? "Defense" : "Prosecution"
    }
}
