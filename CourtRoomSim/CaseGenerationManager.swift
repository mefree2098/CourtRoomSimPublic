// CaseGenerationManager.swift
// CourtRoomSim

import Foundation
import CoreData

struct CaseGenerationManager {

    func generate(into context: NSManagedObjectContext,
                  role: UserRole,
                  model: AiModel,
                  completion: @escaping (Result<CaseEntity, Error>) -> Void)
    {
        let system = "You are a legal scenario generator. Return STRICT JSON only."
        let user = """
        Create a NEW criminal case for a \(role.rawValue). \
        Include at least one victim, at least one suspect, at least two witnesses, and at least one police officer. \
        You may include murder cases. \
        Include exactly these keys: \
        crimeType, scenarioSummary, victim, suspect, witnesses, police, counsel, judge, trueGuiltyParty, groundTruth. \
        The victim and suspect objects may supply their name under 'name', 'representative', or 'organization'. \
        The counsel and judge objects must each have 'name', 'role', and 'background'. \
        Do NOT wrap the JSON in markdown fences.
        """

        OpenAIHelper.shared.chatCompletion(
            model: model.rawValue,
            system: system,
            user: user
        ) { result in
            switch result {
            case .failure(let err):
                completion(.failure(err))
            case .success(let json):
                do {
                    let ce = try Self.makeCaseEntity(
                        fromJSON: json,
                        role: role,
                        model: model,
                        context: context
                    )
                    Self.generatePortraits(for: ce, in: context)
                    completion(.success(ce))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    private static func makeCaseEntity(
        fromJSON json: String,
        role: UserRole,
        model: AiModel,
        context ctx: NSManagedObjectContext
    ) throws -> CaseEntity
    {
        guard
            let data = json.data(using: .utf8),
            let dict = try JSONSerialization.jsonObject(with: data) as? [String:Any]
        else {
            throw OpenAIError.malformed(raw: json)
        }

        let c = CaseEntity(context: ctx)
        c.id           = UUID()
        c.phase        = CasePhase.preTrial.rawValue
        c.userRole     = role.rawValue
        c.aiModel      = model.rawValue
        c.crimeType    = dict["crimeType"] as? String
        c.details      = dict["scenarioSummary"] as? String

        func buildCharacter(from raw: Any?,
                            defaultRole: String,
                            ctx: NSManagedObjectContext) -> CourtCharacter?
        {
            guard let raw = raw else { return nil }
            let info = raw as? [String:Any]
            let name: String?

            if let d = info {
                name = (d["name"] as? String)
                     ?? (d["representative"] as? String)
                     ?? (d["organization"] as? String)
            } else if let s = raw as? String {
                name = s
            } else {
                return nil
            }

            guard let n = name, !n.isEmpty else { return nil }
            let char = CourtCharacter(context: ctx)
            char.id   = UUID()
            char.name = n
            char.role = info?["role"] as? String ?? defaultRole
            char.personality = info?["background"] as? String
            return char
        }

        // Victim & Suspect
        c.victim  = buildCharacter(from: dict["victim"],  defaultRole: "Victim", ctx: ctx)
        c.suspect = buildCharacter(from: dict["suspect"], defaultRole: "Suspect",ctx: ctx)

        // Witnesses (≥2)
        (dict["witnesses"] as? [[String:Any]])?
            .compactMap { buildCharacter(from: $0, defaultRole: "Witness", ctx: ctx) }
            .forEach(c.addToWitnesses)

        // Police (≥1)
        (dict["police"] as? [[String:Any]])?
            .compactMap { buildCharacter(from: $0, defaultRole: "Police", ctx: ctx) }
            .forEach(c.addToPolice)

        // Opposing Counsel
        if let raw = dict["counsel"] as? [String:Any],
           let counselChar = buildCharacter(from: raw, defaultRole: "Counsel", ctx: ctx)
        {
            // Override to the opposite role of the user
            counselChar.role = (role == .prosecutor)
                ? "Defense Counsel"
                : "Prosecutor"
            c.opposingCounsel = counselChar
        }

        // Judge
        if let raw = dict["judge"] as? [String:Any],
           let judgeChar = buildCharacter(from: raw, defaultRole: "Judge", ctx: ctx)
        {
            c.judge = judgeChar
        }

        // True Guilty Party
        if let raw = dict["trueGuiltyParty"] as? [String:Any],
           let tgpChar = buildCharacter(from: raw, defaultRole: "TrueGuilty", ctx: ctx)
        {
            c.trueGuiltyParty = tgpChar
            c.groundTruth     = (dict["groundTruth"] as? Bool) ?? false
        }

        try ctx.save()
        return c
    }

    private static func generatePortraits(for caseEntity: CaseEntity,
                                          in ctx: NSManagedObjectContext)
    {
        var chars: [CourtCharacter] = []
        [caseEntity.victim,
         caseEntity.suspect,
         caseEntity.opposingCounsel,
         caseEntity.judge].compactMap { $0 }.forEach { chars.append($0) }
        chars += (caseEntity.witnesses as? Set<CourtCharacter>) ?? []
        chars += (caseEntity.police    as? Set<CourtCharacter>) ?? []

        guard let apiKey = try? KeychainManager.shared.retrieveAPIKey() else { return }
        for char in chars {
            let prompt = "A pixel‑art portrait of \(char.name!), a \(char.role!) in a courtroom."
            CharacterImageManager.shared.generatePixelArtImage(prompt: prompt,
                                                               apiKey: apiKey) { result in
                if case .success(let data) = result {
                    DispatchQueue.main.async {
                        char.imageData = data
                        try? ctx.save()
                    }
                }
            }
        }
    }
}
