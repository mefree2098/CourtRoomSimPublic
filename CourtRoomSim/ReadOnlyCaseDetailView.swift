// ReadOnlyCaseDetailView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct ReadOnlyCaseDetailView: View {
    let caseEntity: CaseEntity

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(caseEntity.crimeType ?? "Untitled Case")
                    .font(.largeTitle)
                    .bold()
                Text(caseEntity.details ?? "")
                    .font(.body)

                Divider()

                Group {
                    Text("Victim: \(caseEntity.victim?.name ?? "-")")
                    Text("Suspect: \(caseEntity.suspect?.name ?? "-")")
                }

                Divider()

                Text("Opposing Counsel: \(caseEntity.opposingCounsel?.name ?? "-")")
                Text("Judge: \(caseEntity.judge?.name ?? "-")")

                Divider()

                if caseEntity.phase == CasePhase.completed.rawValue {
                    Text("Verdict: \(caseEntity.verdict ?? "-")")
                        .font(.title2)
                        .bold()
                    Text("Your Role: \(caseEntity.userRole ?? "")")
                    Text("AI Model: \(caseEntity.aiModel ?? "")")
                    Text("Justice Served: \(justiceServedText())")
                } else {
                    Text("Current Phase: \(caseEntity.phase ?? "")")
                }

                Divider()

                Text("Transcript")
                    .font(.headline)

                ForEach(transcriptIndices, id: \.self) { idx in
                    let line = transcripts[idx]
                    Text("[\(line.speaker)] \(line.message)")
                        .font(.caption)
                        .padding(.vertical, 2)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Case Overview")
    }

    private var transcripts: [(speaker: String, message: String)] {
        ((caseEntity.trialEvents as? Set<TrialEvent>) ?? [])
            .sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
            .map { ($0.speaker ?? "", $0.message ?? "") }
    }

    private var transcriptIndices: [Int] { Array(transcripts.indices) }

    private func justiceServedText() -> String {
        guard let verdict = caseEntity.verdict else { return "No" }
        let suspectGuilty = caseEntity.groundTruth
        if verdict == "Guilty" && suspectGuilty { return "Yes" }
        if verdict == "Not Guilty" && !suspectGuilty { return "Yes" }
        return "No"
    }
}
