// OpenAIHelper.swift
// CourtRoomSim

import Foundation

/// Errors from the Responses API helper.
enum OpenAIError: Error, LocalizedError {
    case missingKey
    case apiError(message: String)
    case http(Error)
    case malformed(raw: String?)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "No OpenAI API key found. Please configure it in Settings."
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        case .http(let err):
            return "Network error: \(err.localizedDescription)"
        case .malformed(let raw):
            if let raw = raw {
                return "Received malformed response:\n\(raw)"
            } else {
                return "Received malformed response."
            }
        }
    }
}

/// Top‑level decode of the Responses API payload.
private struct ResponsesAPIResponse: Codable {
    let error: APIErrorBody?
    let output: [ResponseOutput]
}

private struct APIErrorBody: Codable {
    let message: String
}

private struct ResponseOutput: Codable {
    let type: String
    let content: [ResponseContent]?
}

private struct ResponseContent: Codable {
    let type: String
    let text: String
}

final class OpenAIHelper {
    static let shared = OpenAIHelper()
    private init() {}

    /// Calls the Responses API and returns just the model’s `output_text` payload.
    func chatCompletion(
        model: String,
        system: String,
        user: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // 1) Retrieve API key
        guard
            let apiKey = UserDefaults.standard.string(forKey: "openAIKey"),
            !apiKey.isEmpty
        else {
            completion(.failure(OpenAIError.missingKey))
            return
        }

        // 2) Build request
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            completion(.failure(OpenAIError.malformed(raw: nil)))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": model,
            "instructions": system,
            "input": user
        ]
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }

        // 3) Perform request
        URLSession.shared.dataTask(with: req) { data, _, error in
            // Network‑level error
            if let err = error {
                completion(.failure(OpenAIError.http(err)))
                return
            }
            guard let data = data else {
                completion(.failure(OpenAIError.malformed(raw: nil)))
                return
            }

            // 4) Decode top‑level response
            do {
                let wrapper = try JSONDecoder().decode(ResponsesAPIResponse.self, from: data)

                // 5) Handle API‑reported error
                if let errBody = wrapper.error {
                    completion(.failure(OpenAIError.apiError(message: errBody.message)))
                    return
                }

                // 6) Find the "message" output block
                guard
                    let messageBlock = wrapper.output.first(where: { $0.type == "message" }),
                    let contents     = messageBlock.content,
                    let outputText   = contents.first(where: { $0.type == "output_text" })?.text
                else {
                    let raw = String(data: data, encoding: .utf8)
                    completion(.failure(OpenAIError.malformed(raw: raw)))
                    return
                }

                // 7) Clean up any fences/quotes around the JSON
                let cleaned = OpenAIHelper.cleanJSON(outputText)
                completion(.success(cleaned))

            } catch {
                // 8) Decoding failed
                let raw = String(data: data, encoding: .utf8)
                completion(.failure(OpenAIError.malformed(raw: raw)))
            }
        }.resume()
    }

    /// Strips markdown fences and wrapping quotes, then trims.
    private static func cleanJSON(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove leading ``` fences or ```json
        if s.hasPrefix("```") {
            // Drop the first line (``` or ```json)
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
        }
        // Remove trailing ``` fence
        if let endFence = s.range(of: "```", options: .backwards) {
            s = String(s[..<endFence.lowerBound])
        }

        // Trim again
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // If wrapped in quotes, drop them
        if s.count >= 2, s.first == "\"", s.last == "\"" {
            s = String(s.dropFirst().dropLast())
        }

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
