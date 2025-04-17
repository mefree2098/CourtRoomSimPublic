//
//  CaseGenerationManager.swift
//  CourtRoomSim
//
//  Responsible for synthesising a brand‑new CaseEntity from OpenAI
//

import Foundation
import CoreData

struct CaseGenerationManager {

    // MARK: – Public façade
    func generate(into context: NSManagedObjectContext,
                  role: UserRole,
                  model: AiModel,
                  completion: @escaping (Result<CaseEntity,Error>) -> Void)
    {
        let system = "You are a legal scenario generator.  Return STRICT JSON only."
        let user =
        """
        Create a NEW criminal case for a \(role.rawValue). \
        Avoid murder every time. Keys required: \
        crimeType, scenarioSummary, victim, suspect, witnesses, police, \
        trueGuiltyParty, groundTruth.
        """

        OpenAIHelper.shared.chatCompletion(model: model.rawValue,
                                           system: system,
                                           user:   user) { result in
            switch result {
            case .failure(let err):
                completion(.failure(err))

            case .success(let json):
                do {
                    let caseEntity = try Self.makeCaseEntity(fromJSON: json,
                                                             role: role,
                                                             model: model,
                                                             context: context)
                    completion(.success(caseEntity))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: – JSON → Core‑Data
    private static func makeCaseEntity(fromJSON json: String,
                                       role:   UserRole,
                                       model:  AiModel,
                                       context ctx: NSManagedObjectContext)
        throws -> CaseEntity
    {
        guard
            let data = json.data(using: .utf8),
            let dict = try JSONSerialization.jsonObject(with: data) as? [String:Any]
        else { throw OpenAIError.malformed }

        let c = CaseEntity(context: ctx)
        c.id        = UUID()
        c.phase     = "PreTrial"
        c.userRole  = role.rawValue
        c.aiModel   = model.rawValue

        c.crimeType = dict["crimeType"]       as? String
        c.details   = dict["scenarioSummary"] as? String

        func addChar(_ name: String?, _ type: String) -> CourtCharacter? {
            guard let n = name, !n.isEmpty else { return nil }
            let ch = CourtCharacter(context: ctx)
            ch.id   = UUID()
            ch.name = n
            ch.role = type
            return ch
        }
        c.victim  = addChar(dict["victim"]  as? String, "Victim")
        c.suspect = addChar(dict["suspect"] as? String, "Suspect")

        (dict["witnesses"] as? [String])?
            .compactMap { addChar($0, "Witness") }
            .forEach(c.addToWitnesses)

        (dict["police"] as? [String])?
            .compactMap { addChar($0, "Police") }
            .forEach(c.addToPolice)

        try ctx.save()
        return c
    }
}
