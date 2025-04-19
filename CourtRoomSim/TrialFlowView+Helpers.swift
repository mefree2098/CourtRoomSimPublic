// TrialFlowView+Helpers.swift
// CourtRoomSim

import Foundation
import SwiftUI

extension TrialFlowView {
    // Compatibility alias for helpers
    func advanceStage() { advanceStageAndPersist() }

    // MARK: – AI Opponent Opening/Closing Statements

    /// AI opponent responds with ONE concise (max 2 sentences) statement, then rests.
    func gptOpponentStatement(userText: String) {
        guard let opp = caseEntity.opposingCounsel else { return }
        let apiKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        guard !apiKey.isEmpty else { return }

        isLoading = true
        let systemPrompt = """
You are \(opp.name ?? "Opposing Counsel"), the \(opp.role ?? "Counsel") in a United States criminal court under the supervision of the presiding judge. Provide exactly ONE concise courtroom statement (no more than two sentences) in response to the opposing counsel. Once finished, explicitly say “I rest my case.”
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
                self.isLoading = false
                switch result {
                case .success(let reply):
                    recordEvent(opp.name ?? "Opposing Counsel", reply)
                    advanceStageAndPersist()
                case .failure(let err):
                    errorMessage = err.localizedDescription
                }
            }
        }
    }

    // MARK: – AI Witness Answer

    /// In‑character witness answer callback.
    func gptWitnessAnswer(
        _ witness: String,
        _ question: String,
        _ context: String,
        _ onReply: @escaping (String) -> Void
    ) {
        let apiKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        guard !apiKey.isEmpty else {
            onReply("No API key")
            return
        }

        isLoading = true
        let systemPrompt = "You are \(witness), answering in first person, no AI references, fully addressing the question based on all prior context."
        let userPrompt = """
Context: \(context)
Q: "\(question)"
"""

        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: userPrompt
        ) { result in
            DispatchQueue.main.async {
                self.isLoading = false
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

    /// AI opponent asks exactly ONE concise question per call, no repeats.
    func gptOpponentCrossExam(
        _ witness: String,
        _ context: String,
        _ askedSoFar: [String],
        _ onNewQuestion: @escaping (String?) -> Void
    ) {
        guard let opp = caseEntity.opposingCounsel else {
            onNewQuestion(nil)
            return
        }
        let apiKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        guard !apiKey.isEmpty else {
            onNewQuestion(nil)
            return
        }

        isLoading = true
        // Determine AI role opposite of user selection
        let userRole = caseEntity.userRole ?? ""
        let aiRoleName: String
        if userRole.lowercased().contains("prosecutor") {
            aiRoleName = "Defense Counsel"
        } else {
            aiRoleName = "Prosecuting Counsel"
        }

        let systemPrompt = """
You are \(opp.name ?? "Opposing Counsel"), the \(aiRoleName) in a United States criminal court under the supervision of the presiding judge. Under the judge’s supervision, ask exactly ONE concise cross‑examination question (no repeats). Do NOT bundle multiple questions.
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
                self.isLoading = false
                switch result {
                case .success(let question):
                    let clean = question.trimmingCharacters(in: .whitespacesAndNewlines)
                    if askedSoFar.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) {
                        recordEvent("Judge", "Counsel, please move on to a different question.")
                        onNewQuestion(nil)
                    } else {
                        onNewQuestion(clean)
                    }
                case .failure:
                    recordEvent("Judge", "Counsel, please proceed.")
                    onNewQuestion(nil)
                }
            }
        }
    }
}
