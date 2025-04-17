// DirectExaminationView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct DirectExaminationView: View {
    // MARK: – Dependencies
    let roleName: String
    @ObservedObject var caseEntity: CaseEntity
    let record: (String, String) -> Void
    let gptAnswer: (_ witness: String,
                    _ q: String,
                    _ ctx: String,
                    _ cb: @escaping (String) -> Void) -> Void
    let gptCross: (_ witness: String,
                   _ ctx: String,
                   _ asked: [String],
                   _ cb: @escaping (String?) -> Void) -> Void
    @Binding var isLoading: Bool
    let lockWitness: Bool
    let finishCase: () -> Void

    // MARK: – UI State
    @State private var selected: CourtCharacter?
    @State private var questionText = ""
    @State private var directSummary = ""
    @State private var step = 0             // 0=direct, 1=cross, 2=redirect, 3=done
    @State private var askedCross: [String] = []
    @State private var askedFirst = false
    @State private var showObj = false
    @State private var objReason = ""

    var body: some View {
        VStack(spacing: 10) {
            Text("\(roleName) Case")
                .font(.headline)

            witnessPicker
            questionBar
            objectButton
            phaseButtons

            Divider()

            Button("Finish Entire \(roleName) Case") {
                finishCase()
            }
            .padding(.top, 4)
        }
        .alert("State your objection", isPresented: $showObj) {
            TextField("Objection reason", text: $objReason)
            Button("Submit") { submitObjection() }
            Button("Cancel", role: .cancel) { objReason = "" }
        }
        .padding()
    }

    // MARK: – UI Components

    private var witnessPicker: some View {
        Group {
            if askedFirst && lockWitness {
                Text(selected?.name ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                Picker("Witness", selection: $selected) {
                    Text("None").tag(CourtCharacter?.none)
                    ForEach(possibleWitnesses, id: \.id) { w in
                        Text(w.name ?? "Witness").tag(CourtCharacter?.some(w))
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
                .disabled(selected == nil || questionText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
    }

    private var objectButton: some View {
        // simplified label
        Button("Object") {
            showObj = true
        }
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
                Button("Finish with this Witness") { nextWitness() }
            }
        }
    }

    // MARK: – Actions

    private func ask() {
        guard let w = selected, let wName = w.name else { return }
        let q = questionText.trimmingCharacters(in: .whitespaces)
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
        askCross()
    }

    private func finishRedirect() {
        step = 3
        askCross()
    }

    /// Centralized cross‑exam loop
    private func askCross() {
        guard let wName = selected?.name else { return }
        gptCross(wName, directSummary, askedCross) { aiQ in
            guard let q = aiQ?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty else {
                record("Judge", "No further questions, your honor.")
                step = step < 2 ? step + 1 : 3
                return
            }
            handleAiCross(q)
        }
    }

    private func submitObjection() {
        let sustained = Bool.random()
        record("Judge", "Objection (\(objReason)). Judge: \(sustained ? "Sustained" : "Overruled")")
        objReason = ""
        if sustained {
            // Immediately loop to next cross question
            askCross()
        }
    }

    private func handleAiCross(_ q: String) {
        let counselName = oppositeRole
        record(counselName, q)
        CrossExamUI.shared.present(question: q) { allowed, reason in
            guard let wName = selected?.name else { return }
            if !allowed {
                // if overruled, proceed; if sustained, loop
                let overruled = Bool.random()
                record("Judge", "\(counselName) objects (\(reason)). Judge: \(overruled ? "Overruled" : "Sustained")")
                if !overruled {
                    // sustained → ask next
                    askCross()
                    return
                }
            }
            // witness answers, then loop
            gptAnswer(wName, q, directSummary) { ans in
                record(wName, ans)
                directSummary += "Q: \(q)\nA: \(ans)\n"
                askedCross.append(q)
                askCross()
            }
        }
    }

    private func nextWitness() {
        let list = possibleWitnesses
        if let current = selected, let idx = list.firstIndex(of: current),
           idx + 1 < list.count
        {
            selected = list[idx + 1]
        } else {
            selected = list.first
        }
        askedFirst = false
        directSummary = ""
        askedCross = []
        step = 0
    }

    // MARK: – Helpers

    private var possibleWitnesses: [CourtCharacter] {
        var set = Set<CourtCharacter>()
        if let w = caseEntity.witnesses as? Set<CourtCharacter> { set.formUnion(w) }
        if let p = caseEntity.police    as? Set<CourtCharacter> { set.formUnion(p) }
        if let sus = caseEntity.suspect { set.insert(sus) }
        if let v = caseEntity.victim,
           !(caseEntity.crimeType?.lowercased().contains("murder") ?? false)
        {
            set.insert(v)
        }
        return Array(set)
    }

    private var oppositeRole: String {
        roleName.lowercased().contains("prosecution") ? "Defense Counsel" : "Prosecutor"
    }
}
