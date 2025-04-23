// OpeningStatementsView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct OpeningStatementsView: View {
    // MARK: – Injected dependencies
    @ObservedObject var caseEntity: CaseEntity
    @Binding var currentSpeaker: String
    var record: (_ speaker: String, _ message: String) -> Void
    var autoOpponent: (_ userText: String) -> Void
    var moveNext: () -> Void
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: – Local state
    @State private var statementText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showNotebook = false

    var body: some View {
        VStack(spacing: 16) {
            Text("\(currentSpeaker)'s Opening Statement")
                .font(.headline)

            TextEditor(text: $statementText)
                .frame(height: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)

            if let err = errorMessage {
                Text(err)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Submit Statement") {
                submitStatement()
            }
            .disabled(statementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .navigationTitle("Opening Statements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submitStatement() {
        let text = statementText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // 1) Record the user's statement in the transcript
        record(currentSpeaker, text)

        // 2) Ask the AI opponent to respond (this will call record + advanceStage)
        isLoading = true
        errorMessage = nil
        autoOpponent(text)
    }
}

// No previews needed since this is wired by TrialFlowView
