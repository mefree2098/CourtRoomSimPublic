// CaseGenerationManager.swift
// CourtRoomSim

import Foundation
import CoreData

struct CaseGenerationManager {

    /// Kick off the AI call to generate a new CaseEntity,
    /// then ensure it contains all required sections—reprompting only for those that are missing.
    func generate(
        into context: NSManagedObjectContext,
        role: UserRole,
        model: AiModel,
        completion: @escaping (Result<CaseEntity, Error>) -> Void
    ) {
        let system = "You are a legal scenario generator. Return STRICT JSON only."
        let user = """
        Create a NEW criminal case for a \(role.rawValue). \
        Include at least one victim, one suspect, two witnesses, one police officer, one counsel, and one judge. \
        You may include murder cases. \
        Keys must be: crimeType, scenarioSummary, victim, suspect, witnesses, police, counsel, judge, trueGuiltyParty, groundTruth. \
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

            case .success(let rawJSON):
                self.fillMissingSections(
                    rawJSON: rawJSON,
                    model: model,
                    systemPrompt: system,
                    context: context,
                    role: role,
                    completion: completion
                )
            }
        }
    }

    // MARK: – Recursively reprompt for missing keys only

    private func fillMissingSections(
        rawJSON: String,
        model: AiModel,
        systemPrompt: String,
        context: NSManagedObjectContext,
        role: UserRole,
        completion: @escaping (Result<CaseEntity, Error>) -> Void
    ) {
        // Parse into a mutable dictionary
        guard
            let data = rawJSON.data(using: .utf8),
            var dict = try? JSONSerialization.jsonObject(with: data) as? [String:Any]
        else {
            completion(.failure(OpenAIError.malformed(raw: rawJSON)))
            return
        }

        // Detect missing sections
        var missing: [String] = []
        if dict["victim"] == nil {
            missing.append("victim")
        }
        if dict["suspect"] == nil {
            missing.append("suspect")
        }
        if let ws = dict["witnesses"] as? [[String:Any]] {
            if ws.count < 2 { missing.append("witnesses") }
        } else {
            missing.append("witnesses")
        }
        if let ps = dict["police"] as? [[String:Any]] {
            if ps.isEmpty { missing.append("police") }
        } else {
            missing.append("police")
        }
        if dict["counsel"] == nil {
            missing.append("counsel")
        }
        if dict["judge"] == nil {
            missing.append("judge")
        }
        // trueGuiltyParty/groundTruth are optional

        // If none missing, finalize
        guard !missing.isEmpty else {
            do {
                let entity = try Self.makeCaseEntity(
                    fromJSON: rawJSON,
                    role: role,
                    model: model,
                    context: context
                )
                Self.generatePortraits(for: entity, in: context)
                completion(.success(entity))
            } catch {
                completion(.failure(error))
            }
            return
        }

        // Reprompt for only the missing keys
        let keys = missing.joined(separator: ", ")
        let followUpUser = """
        Your last response omitted these keys: \(keys). \
        Please provide **only** those keys in strict JSON (no fences), matching the original structure.
        """

        OpenAIHelper.shared.chatCompletion(
            model: model.rawValue,
            system: systemPrompt,
            user: followUpUser
        ) { followResult in
            switch followResult {
            case .failure:
                // On failure, fallback to whatever we have
                do {
                    let entity = try Self.makeCaseEntity(
                        fromJSON: rawJSON,
                        role: role,
                        model: model,
                        context: context
                    )
                    Self.generatePortraits(for: entity, in: context)
                    completion(.success(entity))
                } catch {
                    completion(.failure(error))
                }

            case .success(let followJSON):
                // Merge follow-up into dict
                if
                    let followData = followJSON.data(using: .utf8),
                    let followDict = try? JSONSerialization
                                      .jsonObject(with: followData) as? [String:Any]
                {
                    for key in missing {
                        if let val = followDict[key] {
                            dict[key] = val
                        }
                    }
                }
                // Serialize merged dict back to JSON
                if let mergedData = try? JSONSerialization.data(withJSONObject: dict),
                   let mergedJSON = String(data: mergedData, encoding: .utf8)
                {
                    // Recurse to verify no more missing
                    self.fillMissingSections(
                        rawJSON: mergedJSON,
                        model: model,
                        systemPrompt: systemPrompt,
                        context: context,
                        role: role,
                        completion: completion
                    )
                } else {
                    // If merge fails, fallback
                    do {
                        let entity = try Self.makeCaseEntity(
                            fromJSON: rawJSON,
                            role: role,
                            model: model,
                            context: context
                        )
                        Self.generatePortraits(for: entity, in: context)
                        completion(.success(entity))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    // MARK: – Build the Core Data entity

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
        c.id        = UUID()
        c.phase     = CasePhase.preTrial.rawValue
        c.userRole  = role.rawValue
        c.aiModel   = model.rawValue
        c.crimeType = dict["crimeType"] as? String
        c.details   = dict["scenarioSummary"] as? String

        func build(_ raw: Any?, defaultRole: String) -> CourtCharacter? {
            guard let raw = raw else { return nil }
            let info = raw as? [String:Any]
            let name: String? = {
                if let d = info {
                    return (d["name"] as? String)
                        ?? (d["representative"] as? String)
                        ?? (d["organization"] as? String)
                } else {
                    return raw as? String
                }
            }()
            guard let n = name, !n.isEmpty else { return nil }
            let char = CourtCharacter(context: ctx)
            char.id          = UUID()
            char.name        = n
            char.role        = info?["role"] as? String ?? defaultRole
            char.personality = info?["background"] as? String
            return char
        }

        c.victim  = build(dict["victim"],  defaultRole: "Victim")
        c.suspect = build(dict["suspect"], defaultRole: "Suspect")
        (dict["witnesses"] as? [[String:Any]])?
            .compactMap { build($0, defaultRole: "Witness") }
            .forEach(c.addToWitnesses)
        (dict["police"] as? [[String:Any]])?
            .compactMap { build($0, defaultRole: "Police") }
            .forEach(c.addToPolice)

        if let rawC = dict["counsel"] as? [String:Any],
           let counselChar = build(rawC, defaultRole: "Counsel")
        {
            counselChar.role = (role == .prosecutor)
                ? "Defense Counsel" : "Prosecutor"
            c.opposingCounsel = counselChar
        }

        if let rawJ = dict["judge"] as? [String:Any],
           let judgeChar = build(rawJ, defaultRole: "Judge")
        {
            c.judge = judgeChar
        }

        if let rawT = dict["trueGuiltyParty"] as? [String:Any],
           let tgpChar = build(rawT, defaultRole: "TrueGuilty")
        {
            c.trueGuiltyParty = tgpChar
            c.groundTruth     = (dict["groundTruth"] as? Bool) ?? false
        }

        try ctx.save()
        return c
    }

    // MARK: – Portrait Generation (UserDefaults → Keychain fallback)

    private static func generatePortraits(
        for caseEntity: CaseEntity,
        in ctx: NSManagedObjectContext
    ) {
        // gather all characters
        var chars: [CourtCharacter] = []
        [caseEntity.victim, caseEntity.suspect,
         caseEntity.opposingCounsel, caseEntity.judge]
            .compactMap { $0 }.forEach { chars.append($0) }
        chars += (caseEntity.witnesses as? Set<CourtCharacter>) ?? []
        chars += (caseEntity.police    as? Set<CourtCharacter>) ?? []

        // 1) Try UserDefaults
        let defaultKey = UserDefaults.standard.string(forKey: "openAIKey")?
                          .trimmingCharacters(in: .whitespaces)
        // 2) Fallback to Keychain
        let chainKey = (try? KeychainManager.shared.retrieveAPIKey())?
                          .trimmingCharacters(in: .whitespaces)
        let apiKey = (defaultKey?.isEmpty == false ? defaultKey : chainKey) ?? ""

        guard !apiKey.isEmpty else { return }

        for char in chars {
            let prompt = "A pixel‑art portrait of \(char.name!), a \(char.role!) in a courtroom."
            func attempt() {
                CharacterImageManager.shared.generatePixelArtImage(
                    prompt: prompt,
                    apiKey: apiKey
                ) { result in
                    switch result {
                    case .success(let data):
                        DispatchQueue.main.async {
                            char.imageData = data
                            try? ctx.save()
                        }
                    case .failure:
                        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                            CharacterImageManager.shared.generatePixelArtImage(
                                prompt: prompt,
                                apiKey: apiKey
                            ) { retry in
                                if case .success(let data2) = retry {
                                    DispatchQueue.main.async {
                                        char.imageData = data2
                                        try? ctx.save()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            attempt()
        }
    }
}
