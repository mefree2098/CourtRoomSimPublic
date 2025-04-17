//
//  OpeningStatementsView.swift
//  CourtRoomSim
//
//  FULL SOURCE – 2025‑05‑01
//

import SwiftUI
import CoreData

struct OpeningStatementsView: View {

    // injected
    @ObservedObject var caseEntity: CaseEntity
    @Binding var currentSpeaker: String
    let record: (String, String) -> Void
    let autoOpponent: (String) -> Void
    let moveNext: () -> Void          // <— single, consistent label

    // local
    @State private var text = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Opening Statement – \(currentSpeaker)")
                .font(.headline)

            TextEditor(text: $text)
                .frame(minHeight: 90)
                .border(Color.gray)
                .padding(.horizontal)

            Button("Submit") {
                let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else { return }
                record(currentSpeaker, clean)
                text = ""
                autoOpponent(clean)     // AI replies; that will in turn call moveNext
            }
            .padding(.bottom, 4)

            Button("Skip to Next Stage") { moveNext() }
                .font(.caption)
        }
        .padding(.vertical)
    }
}
