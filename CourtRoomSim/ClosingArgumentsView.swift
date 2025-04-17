//
//  ClosingArgumentsView.swift
//  CourtRoomSim
//
//  FULL SOURCE – 2025‑05‑01
//

import SwiftUI
import CoreData

struct ClosingArgumentsView: View {

    @ObservedObject var caseEntity: CaseEntity
    @Binding var currentSpeaker: String
    let record: (String, String) -> Void
    let autoOpponent: (String) -> Void
    let moveNext: () -> Void          // <— same label as above

    @State private var text = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Closing – \(currentSpeaker)")
                .font(.headline)

            TextEditor(text: $text)
                .frame(minHeight: 80)
                .border(Color.gray)
                .padding(.horizontal)

            Button("Submit Closing") {
                let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else { return }
                record(currentSpeaker, clean)
                text = ""
                autoOpponent(clean)     // AI rebuttal; will then trigger moveNext
            }

            Button("Finish Closing Phase") { moveNext() }
                .padding(.top, 4)
        }
        .padding(.vertical)
    }
}
