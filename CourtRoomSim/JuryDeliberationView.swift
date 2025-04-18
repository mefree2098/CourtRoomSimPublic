// JuryDeliberationView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct JuryDeliberationView: View {
    @ObservedObject var caseEntity: CaseEntity
    let recordTranscript: (String, String) -> Void
    let finalizeVerdict: (String) -> Void

    @State private var transcript: [(speaker: String, message: String)] = []
    @State private var isLoading = true

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Deliberating…")
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(transcript.indices, id: \.self) { i in
                            let line = transcript[i]
                            HStack(alignment: .top) {
                                Text(line.speaker).bold()
                                Text(line.message)
                            }
                        }
                    }
                    .padding()
                }
                Button("Finish Case") {
                    // If we parsed a final verdict, pass it back
                    if let last = transcript.last,
                       last.speaker == "Final Verdict" {
                        finalizeVerdict(last.message)
                    }
                    // Mark the case completed
                    caseEntity.phase = CasePhase.completed.rawValue
                }
                .padding()
            }
        }
        .navigationTitle("Jury Deliberation")
        .onAppear(perform: startDeliberation)
    }

    private func startDeliberation() {
        let juryNames = (caseEntity.jury as? Set<CourtCharacter>)?
            .map { $0.name ?? "Juror" }
            .joined(separator: ", ")
            ?? "Juror 1, Juror 2, …, Juror 12"

        let systemPrompt = """
        You are 12 jurors in a United States criminal trial. \
        Deliberate as Juror 1…Juror 12 about the facts: \(caseEntity.details ?? "") \
        Aim for a unanimous verdict and role‑play convincing arguments. \
        At the end, output “Verdict: Guilty” or “Verdict: Not Guilty” on its own line.
        """
        let userPrompt = "Jurors: \(juryNames)"

        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: userPrompt
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let text):
                    parse(text)
                case .failure:
                    transcript = [("Judge", "Deliberation failed.")]
                }
            }
        }
    }

    private func parse(_ text: String) {
        transcript.removeAll()
        let lines = text.split(separator: "\n").map(String.init)
        for line in lines {
            if line.hasPrefix("Verdict:") {
                let v = line
                    .replacingOccurrences(of: "Verdict:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                recordTranscript("Final Verdict", v)
                transcript.append((speaker: "Final Verdict", message: v))
            } else if let idx = line.firstIndex(of: ":") {
                let speaker = String(line[..<idx])
                let msg = String(line[line.index(after: idx)...])
                    .trimmingCharacters(in: .whitespaces)
                recordTranscript(speaker, msg)
                transcript.append((speaker: speaker, message: msg))
            }
        }
    }
}
