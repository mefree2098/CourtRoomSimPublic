//
//  OpenAIHelper.swift
//  CourtRoomSim
//
//  A tiny, thread‑safe singleton that wraps the OpenAI chat‑completion API.
//  Nothing here is UI‑specific.
//

import Foundation

enum OpenAIError: Error { case missingKey, malformed, http(Error) }

final class OpenAIHelper {

    static let shared = OpenAIHelper()
    private init() {}

    /// Asks Chat Completion and returns raw text.
    func chatCompletion(model: String,
                        system: String,
                        user: String,
                        maxTokens: Int = 256,
                        temperature: Double = 0.7,
                        completion: @escaping (Result<String,Error>) -> Void)
    {
        guard
            let apiKey = UserDefaults.standard.string(forKey:"openAIKey"),
            !apiKey.isEmpty
        else { completion(.failure(OpenAIError.missingKey)); return }

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions")
        else { completion(.failure(OpenAIError.malformed)); return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)",    forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": model,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "messages": [
                ["role":"system", "content": system],
                ["role":"user",   "content": user  ]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error { completion(.failure(OpenAIError.http(error))); return }
            guard
                let data,
                let root = try? JSONSerialization.jsonObject(with:data) as? [String:Any],
                let choices = root["choices"] as? [[String:Any]],
                let message = choices.first?["message"] as? [String:Any],
                let content = message["content"] as? String
            else { completion(.failure(OpenAIError.malformed)); return }

            completion(.success(content.trimmingCharacters(in:.whitespacesAndNewlines)))
        }.resume()
    }
}
