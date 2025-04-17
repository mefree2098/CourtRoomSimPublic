// TrialFlowView+Helpers.swift
// CourtRoomSim

import Foundation
import SwiftUI

extension TrialFlowView {

    // MARK: – AI Opponent Opening/Closing Statements

    /// AI opponent responds with ONE concise (max 2 sentences) statement, then rests.
    func gptOpponentStatement(userText: String) {
        guard let opp = caseEntity.opposingCounsel else { return }
        let apiKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        guard !apiKey.isEmpty else { return }

        isLoading = true
        let systemPrompt = """
        You are \(opp.name ?? "Opposing Counsel"), the \(opp.role ?? "Counsel"). \
        Provide exactly ONE concise courtroom statement (no more than two sentences) in response to the opposing counsel. \
        Once you finish, explicitly state "I rest my case."
        """
        let userPrompt = """
        Opponent said: "\(userText)"
        Case summary: \(caseEntity.details ?? "")
        """

        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: userPrompt
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let reply):
                    recordEvent(opp.name ?? "Opposing Counsel", reply)
                    advanceStage()
                case .failure(let err):
                    errorMessage = err.localizedDescription
                }
            }
        }
    }

    // MARK: – AI Witness Answer

    func gptWitnessAnswer(
        witness: String,
        question: String,
        context: String,
        onReply: @escaping (String) -> Void
    ) {
        let apiKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        guard !apiKey.isEmpty else {
            onReply("No API key")
            return
        }

        isLoading = true
        let systemPrompt = "You are \(witness), answering in first person, no AI references."
        let userPrompt = """
        Q: "\(question)"
        Context: \(context)
        """

        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: userPrompt
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let text):
                    onReply(text)
                case .failure:
                    onReply("…")
                }
            }
        }
    }

    // MARK: – AI Opponent Cross‑Exam

    /// Asks exactly ONE question per call, then stops.
    func gptOpponentCrossExam(
        witness: String,
        context: String,
        askedSoFar: [String],
        onNewQuestion: @escaping (String?) -> Void
    ) {
        guard let opp = caseEntity.opposingCounsel else {
            onNewQuestion(nil); return
        }
        let apiKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        guard !apiKey.isEmpty else {
            onNewQuestion(nil); return
        }

        isLoading = true
        let systemPrompt = """
        You are \(opp.name ?? "Opposing Counsel"), the \(opp.role ?? "Counsel"). \
        Provide exactly ONE concise cross‑examination question (no repeats). \
        Do NOT bundle multiple questions.
        """
        let userPrompt = """
        Already asked: \(askedSoFar.joined(separator: " | "))
        Witness: \(witness)
        Context: \(context)
        """

        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: userPrompt
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let question):
                    let clean = question.trimmingCharacters(in: .whitespacesAndNewlines)
                    if askedSoFar.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) {
                        onNewQuestion(nil)
                    } else {
                        onNewQuestion(clean)
                    }
                case .failure:
                    onNewQuestion(nil)
                }
            }
        }
    }
}
