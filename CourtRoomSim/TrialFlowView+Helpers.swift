// TrialFlowView+Helpers.swift
// CourtRoomSim

import Foundation
import SwiftUI
import CoreData

extension TrialFlowView {
    // Alias for backward compatibility
    func advanceStage() { advanceStageAndPersist() }

    // MARK: – AI Opponent Opening/Closing Statements

    func gptOpponentStatement(userText: String) {
        guard let opp = caseEntity.opposingCounsel else { return }
        let apiKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        guard !apiKey.isEmpty else { return }

        isLoading = true

        // Full trial transcript
        let transcript = trialEvents
            .map { "\($0.speaker): \($0.message)" }
            .joined(separator: "\n")

        // Latest AI plan
        let planFetch: NSFetchRequest<AIPlan> = AIPlan.fetchRequest()
        planFetch.predicate = NSPredicate(format: "caseEntity == %@", caseEntity)
        let planText = (try? viewContext.fetch(planFetch))?.first?.planText ?? ""

        let systemPrompt = """
        You are \(opp.name ?? "Opposing Counsel"), the \
        \(isUserProsecutor ? "Defense Counsel" : "Prosecuting Counsel") in a US criminal court.
        Case summary: \(caseEntity.details ?? "")
        AI plan so far: \(planText)
        Trial transcript so far:
        \(transcript)
        Respond exactly once (≤2 sentences), then say “I rest my case.”
        """
        let userPrompt = "Opponent statement request after: \"\(userText)\""

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
                    advanceStageAndPersist()
                case .failure(let err):
                    errorMessage = err.localizedDescription
                }
            }
        }
    }

    // MARK: – AI Witness Answer

    func gptWitnessAnswer(
        _ witnessName: String,
        _ _question: String,
        _ context: String,
        _ onReply: @escaping (String) -> Void
    ) {
        let apiKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        guard !apiKey.isEmpty else {
            onReply("No API key"); return
        }

        isLoading = true

        // Identify the character entity for additional context
        let allChars = ([caseEntity.victim] +
                        (caseEntity.witnesses as? [CourtCharacter] ?? []) +
                        (caseEntity.police as? [CourtCharacter] ?? []) +
                        [caseEntity.suspect, caseEntity.opposingCounsel]).compactMap { $0 }
        let charEnt = allChars.first(where: { $0.name == witnessName })

        let personality = charEnt?.personality ?? ""
        let background  = charEnt?.background  ?? ""
        let roleDesc    = charEnt?.role        ?? ""

        // Pre‑trial conversation
        let convFetch: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        convFetch.predicate = NSPredicate(
            format: "caseEntity == %@ AND phase == %@",
            caseEntity, CasePhase.preTrial.rawValue
        )
        convFetch.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
        let preHistory = (try? viewContext.fetch(convFetch))?
            .map { "\($0.sender ?? ""): \($0.message ?? "")" }
            .joined(separator: "\n") ?? ""

        // Trial transcript
        let transcript = trialEvents
            .map { "\($0.speaker): \($0.message)" }
            .joined(separator: "\n")

        let systemPrompt = """
        You are \(witnessName), \(roleDesc). Personality: \(personality). Background: \(background).
        Case summary: \(caseEntity.details ?? "")
        Pre‑trial conversation:
        \(preHistory)
        Trial transcript so far:
        \(transcript)
        Answer the question in first person, fully addressing it.
        """

        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: _question
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let text): onReply(text)
                case .failure:          onReply("…")
                }
            }
        }
    }

    // MARK: – AI Opponent Cross‑Exam

    func gptOpponentCrossExam(
        _ witness: String,
        _ _context: String,
        _ askedSoFar: [String],
        _ onNewQuestion: @escaping (String?) -> Void
    ) {
        guard let opp = caseEntity.opposingCounsel else {
            onNewQuestion(nil); return
        }
        let apiKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        guard !apiKey.isEmpty else {
            onNewQuestion(nil); return
        }

        isLoading = true

        let transcript = trialEvents
            .map { "\($0.speaker): \($0.message)" }
            .joined(separator: "\n")
        let planText = (try? viewContext.fetch(
            NSFetchRequest<AIPlan>(entityName: "AIPlan")
        ))?.first?.planText ?? ""
        let aiRole = isUserProsecutor ? "Defense Counsel" : "Prosecuting Counsel"

        let systemPrompt = """
        You are \(opp.name ?? "Opposing Counsel"), the \(aiRole).
        Case summary: \(caseEntity.details ?? "")
        AI plan so far: \(planText)
        Trial transcript so far:
        \(transcript)
        Already asked: \(askedSoFar.joined(separator: " | "))
        Ask one concise cross‑exam question (no repeats).
        """

        OpenAIHelper.shared.chatCompletion(
            model: caseEntity.aiModel ?? AiModel.o4Mini.rawValue,
            system: systemPrompt,
            user: ""
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let q):
                    let clean = q.trimmingCharacters(in: .whitespacesAndNewlines)
                    if askedSoFar.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) {
                        recordEvent("Judge", "Counsel, please move on.")
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
