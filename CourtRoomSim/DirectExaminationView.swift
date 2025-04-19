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

    // MARK: – UI State
    @State private var selected: CourtCharacter?
    @State private var questionText = ""
    @State private var directSummary = ""
    @State private var step = 0             // 0=direct, 1=cross, 2=redirect, 3=done
    @State private var askedCross: [String] = []
    @State private var askedFirst = false

    @State private var pendingCrossQuestion: String? = nil
    @State private var showObjectionInput = false
    @State private var objectionText = ""

    // Limit cross-examination to prevent infinite loops
    private let crossQuestionLimit = 5

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

            Divider()

            // Phase UI
            if step == 0 {
                // Direct examination entry
                HStack {
                    TextField("Ask a question…", text: $questionText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Ask") { ask() }
                        .disabled(selected == nil || questionText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)

                Button("Done with Direct") {
                    finishDirect()
                }
                .disabled(selected == nil)
                .padding(.horizontal)

            } else if let q = pendingCrossQuestion {
                // AI cross-examination question
                Text(q)
                    .padding()
                    .multilineTextAlignment(.center)

                HStack {
                    Button("Object") {
                        showObjectionInput = true
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Proceed") {
                        proceedCross()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

            } else if step == 1 {
                // Move to re-direct phase
                Button("Proceed to Re‑Direct") {
                    step = 2
                }
                .disabled(isLoading)
                .padding(.horizontal)

            } else if step == 2 {
                // Re-direct examination entry
                HStack {
                    TextField("Ask re‑direct question…", text: $questionText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Ask") { askRedirect() }
                        .disabled(questionText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)

                Button("Done with Re‑Direct") {
                    finishRedirect()
                }
                .padding(.horizontal)

            } else if step == 3 {
                // Finish with this witness
                Button("Finish with this Witness") {
                    nextWitness()
                }
                .padding(.horizontal)
            }

            Divider()

            // End entire case
            Button("Finish Entire \(roleName) Case") {
                finishCase()
            }
            .padding(.top, 4)
        }
        // Objection input sheet
        .sheet(isPresented: $showObjectionInput) {
            NavigationView {
                Form {
                    Section(header: Text("Your Objection")) {
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
        .padding()
    }

    // MARK: – Actions

    private func ask() {
        guard let w = selected, let name = w.name else { return }
        let q = questionText.trimmingCharacters(in: .whitespaces)
        askedFirst = true
        record(roleName, "Q(\(name)): \(q)")
        questionText = ""
        gptAnswer(name, q, directSummary) { ans in
            record(name, ans)
            directSummary += "Q: \(q)\nA: \(ans)\n"
        }
    }

    private func finishDirect() {
        step = 1
        askCross()
    }

    private func askCross() {
        guard let name = selected?.name else { return }
        // Prevent infinite loop
        if askedCross.count >= crossQuestionLimit {
            record("Judge", "No further questions, your honor.")
            step = 2
            return
        }
        pendingCrossQuestion = nil
        gptCross(name, directSummary, askedCross) { aiQ in
            if let q = aiQ?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
                // Record AI counsel question
                record(oppositeRole, q)
                pendingCrossQuestion = q
            } else {
                record("Judge", "No further questions, your honor.")
                step = 2
            }
        }
    }

    private func proceedCross() {
        guard let q = pendingCrossQuestion,
              let name = selected?.name else { return }
        pendingCrossQuestion = nil
        askedCross.append(q)
        gptAnswer(name, q, directSummary) { ans in
            record(name, ans)
            directSummary += "Q: \(q)\nA: \(ans)\n"
            askCross()
        }
    }

    private func askRedirect() {
        guard let w = selected, let name = w.name else { return }
        let q = questionText.trimmingCharacters(in: .whitespaces)
        record(roleName, "Q(\(name)): \(q)")
        questionText = ""
        gptAnswer(name, q, directSummary) { ans in
            record(name, ans)
            directSummary += "Q: \(q)\nA: \(ans)\n"
        }
    }

    private func finishRedirect() {
        step = 3
    }

    private func submitObjection() {
        showObjectionInput = false
        record("Judge", "Objection (\(objectionText)).")
        let sustained = Bool.random()
        record("Judge", "Judge: \(sustained ? "Sustained" : "Overruled")")
        let action = sustained ? askCross : proceedCross
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            action()
        }
        objectionText = ""
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
