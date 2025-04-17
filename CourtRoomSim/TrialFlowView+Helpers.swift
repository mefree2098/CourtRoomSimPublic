import Foundation
import SwiftUI

// MARK: – GPT helper extension (single source‑of‑truth)

extension TrialFlowView {

    // --------------------------------------------------------------
    // convenience flags
    // --------------------------------------------------------------

    var isUserProsecutorFlag: Bool {
        (caseEntity.userRole ?? "").lowercased().contains("prosecutor")
    }

    // --------------------------------------------------------------
    // GPT wrappers
    // --------------------------------------------------------------

    /// One short opponent statement then advance stage.
    func gptOpponentStatement(userText: String) {
        guard let opp = caseEntity.opposingCounsel else { return }
        guard let key = UserDefaults.standard.string(forKey: "openAIKey"),
              !key.isEmpty else { return }

        isLoading = true
        let role = isUserProsecutorFlag ? "Defense" : "Prosecution"

        OpenAIRequest.send(
            model:  caseEntity.aiModel ?? "o4-mini",
            system: "You are \(opp.name ?? role) giving ONE short courtroom statement.",
            user:   "User said: \"\(userText)\"  Case: \(caseEntity.details ?? "")",
            apiKey: key
        ) { result in
            DispatchQueue.main.async {                             // capture `self` strongly – no retain cycle
                self.isLoading = false
                if case .success(let reply) = result {
                    self.recordEvent(role, reply)
                    self.advanceStage()
                }
            }
        }
    }

    /// In‑character witness answer.
    func gptWitnessAnswer(witness: String,
                          question: String,
                          context: String,
                          onReply: @escaping (String) -> Void)
    {
        guard let key = UserDefaults.standard.string(forKey: "openAIKey"),
              !key.isEmpty else { onReply("No API key"); return }

        isLoading = true

        OpenAIRequest.send(
            model:  caseEntity.aiModel ?? "o4-mini",
            system: "You are \(witness) answering in first person, no AI references.",
            user:
            """
            Q: "\(question)"
            Context so far:
            \(context)
            """,
            apiKey: key,
            temperature: 0.6
        ) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                onReply((try? result.get()) ?? "…")
            }
        }
    }

    /// Opposing‑counsel cross‑exam question (avoids repeats).
    func gptOpponentCrossExam(witness: String,
                              context: String,
                              askedSoFar: [String],
                              onNewQuestion: @escaping (String?) -> Void)
    {
        guard let opp = caseEntity.opposingCounsel else { onNewQuestion(nil); return }
        guard let key = UserDefaults.standard.string(forKey: "openAIKey"),
              !key.isEmpty else { onNewQuestion(nil); return }

        let role = isUserProsecutorFlag ? "Defense" : "Prosecution"
        var attempts = 0

        func attempt() {
            attempts += 1
            if attempts > 3 { onNewQuestion(nil); return }

            OpenAIRequest.send(
                model:  caseEntity.aiModel ?? "o4-mini",
                system: "You are \(opp.name ?? role) asking ONE cross‑exam question.",
                user:
                """
                Do NOT repeat: \(askedSoFar.joined(separator:" | "))
                Witness: \(witness)
                Context:
                \(context)
                """,
                apiKey: key,
                temperature: 0.6
            ) { result in
                switch result {
                case .failure:
                    attempt()       // retry on transient error
                case .success(let q):
                    let clean = q.trimmingCharacters(in: .whitespacesAndNewlines)
                    if askedSoFar.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) {
                        attempt()
                    } else {
                        onNewQuestion(clean)
                    }
                }
            }
        }
        attempt()
    }
}
