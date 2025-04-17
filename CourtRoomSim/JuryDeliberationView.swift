//
//  JuryDeliberationView.swift
//  CourtRoomSim
//
//  FULL SOURCE – 2025‑05‑02
//

import SwiftUI
import CoreData

struct JuryDeliberationView: View {

    @ObservedObject var caseEntity: CaseEntity
    let recordTranscript: (String, String) -> Void
    let finalizeVerdict:  (String) -> Void

    @State private var deliberating = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Jury Deliberation").font(.headline)

            if deliberating {
                ProgressView("Deliberating…")
            } else {
                Button("Begin Deliberation") { deliberate() }
            }
        }
        .padding()
    }

    private func deliberate() {
        deliberating = true
        DispatchQueue.global().async {
            let votes = (0..<12).map { _ in Bool.random() }
            let guilty = votes.filter { $0 }.count
            let verdict =
                  guilty == 12 ? "Guilty"
                : guilty == 0  ? "Not Guilty"
                :               "Hung Jury"

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.recordTranscript("Jury",
                    "Vote – Guilty \(guilty) / Not \(12 - guilty)")
                self.finalizeVerdict(verdict)
                self.deliberating = false
            }
        }
    }
}
