// CaseGenerationManager.swift
// CourtRoomSim

import Foundation
import CoreData

struct CaseGenerationManager {
    /// Generate a new CaseEntity in one function‐calling API call.
    func generate(
        into context: NSManagedObjectContext,
        role: UserRole,
        model: AiModel,
        completion: @escaping (Result<CaseEntity, Error>) -> Void
    ) {
        // 1) Gather API key (UserDefaults → Keychain)
        let defaultKey = UserDefaults.standard.string(forKey: "openAIKey")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let chainKey = (try? KeychainManager.shared.retrieveAPIKey())?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = (defaultKey?.isEmpty == false ? defaultKey! : chainKey) ?? ""
        guard !apiKey.isEmpty else {
            return completion(.failure(OpenAIError.missingKey))
        }

        // 2) System / user prompts
        let systemPrompt = "You are a legal scenario generator. Return STRICT JSON only."
        let userPrompt = """
        Create a NEW criminal case for a \(role.rawValue). \
        Include at least one victim, one suspect, two witnesses, one police officer, one counsel, and one judge. \
        You may include murder cases. \
        Keys must be: crimeType, scenarioSummary, victim, suspect, witnesses, police, counsel, judge, trueGuiltyParty, groundTruth. \
        Do NOT wrap the JSON in markdown fences.
        """

        // 3) Define function schema
        let functionSchema: [String: Any] = [
            "name": "create_case",
            "description": "Generate a full criminal case JSON",
            "parameters": [
                "type": "object",
                "properties": [
                    "crimeType": ["type": "string"],
                    "scenarioSummary": ["type": "string"],
                    "victim": ["$ref": "#/definitions/Character"],
                    "suspect": ["$ref": "#/definitions/Character"],
                    "witnesses": [
                        "type": "array",
                        "items": ["$ref": "#/definitions/Character"],
                        "minItems": 2
                    ],
                    "police": [
                        "type": "array",
                        "items": ["$ref": "#/definitions/Character"],
                        "minItems": 1
                    ],
                    "counsel": ["$ref": "#/definitions/Character"],
                    "judge": ["$ref": "#/definitions/Character"],
                    "trueGuiltyParty": ["$ref": "#/definitions/Character"],
                    "groundTruth": ["type": "boolean"]
                ],
                "required": [
                    "crimeType",
                    "scenarioSummary",
                    "victim",
                    "suspect",
                    "witnesses",
                    "police",
                    "counsel",
                    "judge"
                ],
                "definitions": [
                    "Character": [
                        "type": "object",
                        "properties": [
                            "name": ["type": "string"],
                            "role": ["type": "string"],
                            "background": ["type": "string"]
                        ],
                        "required": ["name","role"]
                    ]
                ]
            ]
        ]

        // 4) Build request payload
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user",   "content": userPrompt]
        ]
        let payload: [String: Any] = [
            "model": model.rawValue,
            "messages": messages,
            "functions": [functionSchema],
            "function_call": ["name": "create_case"]
        ]

        guard
            let url = URL(string: "https://api.openai.com/v1/chat/completions"),
            let body = try? JSONSerialization.data(withJSONObject: payload)
        else {
            return completion(.failure(OpenAIError.malformed(raw: nil)))
        }

        // 5) Send the HTTP request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json",        forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, _, error in
            // Network error
            if let err = error {
                return DispatchQueue.main.async {
                    completion(.failure(err))
                }
            }
            guard let data = data else {
                return DispatchQueue.main.async {
                    completion(.failure(OpenAIError.malformed(raw: nil)))
                }
            }

            do {
                // 6) Decode function‐calling response
                let resp = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                guard
                    let fn = resp.choices.first?.message.function_call,
                    let argsData = fn.arguments.data(using: .utf8),
                    let jsonString = String(data: argsData, encoding: .utf8)
                else {
                    let raw = String(data: data, encoding: .utf8)
                    throw OpenAIError.malformed(raw: raw)
                }

                // 7) Build Core Data objects
                let entity = try Self.makeCaseEntity(
                    fromJSON: jsonString,
                    role: role,
                    model: model,
                    context: context
                )
                Self.generatePortraits(for: entity, in: context)

                DispatchQueue.main.async {
                    completion(.success(entity))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: – JSON → Core Data mapping

    private static func makeCaseEntity(
        fromJSON json: String,
        role: UserRole,
        model: AiModel,
        context ctx: NSManagedObjectContext
    ) throws -> CaseEntity {
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

        c.victim = build(dict["victim"],  defaultRole: "Victim")
        c.suspect = build(dict["suspect"], defaultRole: "Suspect")

        (dict["witnesses"] as? [[String:Any]])?
            .compactMap { build($0, defaultRole: "Witness") }
            .forEach(c.addToWitnesses)

        (dict["police"] as? [[String:Any]])?
            .compactMap { build($0, defaultRole: "Police") }
            .forEach(c.addToPolice)

        if
            let rawC = dict["counsel"] as? [String:Any],
            let counselChar = build(rawC, defaultRole: "Counsel")
        {
            // Opposing counsel is opposite of user role
            counselChar.role = (role == .prosecutor)
                ? "Defense Counsel"
                : "Prosecutor"
            c.opposingCounsel = counselChar
        }

        if
            let rawJ = dict["judge"] as? [String:Any],
            let judgeChar = build(rawJ, defaultRole: "Judge")
        {
            c.judge = judgeChar
        }

        if
            let rawT = dict["trueGuiltyParty"] as? [String:Any],
            let tgpChar = build(rawT, defaultRole: "TrueGuilty")
        {
            c.trueGuiltyParty = tgpChar
            c.groundTruth     = (dict["groundTruth"] as? Bool) ?? false
        }

        try ctx.save()
        return c
    }

    // MARK: – Portrait generation

    private static func generatePortraits(
        for caseEntity: CaseEntity,
        in ctx: NSManagedObjectContext
    ) {
        // Collect all characters
        var chars: [CourtCharacter] = []
        [caseEntity.victim, caseEntity.suspect,
         caseEntity.opposingCounsel, caseEntity.judge]
            .compactMap { $0 }
            .forEach { chars.append($0) }
        chars += (caseEntity.witnesses as? Set<CourtCharacter>) ?? []
        chars += (caseEntity.police    as? Set<CourtCharacter>) ?? []

        // API key fallback
        let defaultKey = UserDefaults.standard.string(forKey: "openAIKey")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let chainKey = (try? KeychainManager.shared.retrieveAPIKey())?
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
                            attempt()
                        }
                    }
                }
            }
            attempt()
        }
    }
}

// MARK: – Chat Completions function‐calling support

fileprivate struct ChatCompletionResponse: Codable {
    let choices: [ChatChoice]
}
fileprivate struct ChatChoice: Codable {
    let message: ChatMessage
}
fileprivate struct ChatMessage: Codable {
    let role: String
    let content: String?
    let function_call: FunctionCall?
}
fileprivate struct FunctionCall: Codable {
    let name: String
    let arguments: String
}
