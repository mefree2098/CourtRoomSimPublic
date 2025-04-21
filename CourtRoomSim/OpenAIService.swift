// CourtRoomSim/Services/OpenAIService.swift

import Foundation
import UIKit

enum APIError: Error, LocalizedError {
    case noData
    case invalidResponse
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .noData:
            return "No data was returned."
        case .invalidResponse:
            return "Received an unexpected response."
        case .noAPIKey:
            return "No OpenAI API key found. Please configure it in Settings."
        }
    }
}

// MARK: – Models for Reciprocal Objections

struct ObjectionResponse: Codable {
    let objection: Bool
    let reason: String?
}

struct JudgeDecision: Codable {
    let decision: String
}

final class OpenAIService {
    static let shared = OpenAIService()
    private init() {}

    private let maxRetryAttempts = 2

    // MARK: – Text Generation

    func generateText(prompt: String,
                      maxTokens: Int = 300,
                      completion: @escaping (Result<String, Error>) -> Void) {
        generateChatTextInternal(prompt: prompt,
                                 maxTokens: maxTokens,
                                 retryCount: 0,
                                 completion: completion)
    }

    private func generateChatTextInternal(prompt: String,
                                          maxTokens: Int,
                                          retryCount: Int,
                                          completion: @escaping (Result<String, Error>) -> Void) {
        // 1) Retrieve API key (Keychain first, then UserDefaults fallback)
        let apiKey: String
        do {
            apiKey = try KeychainManager.shared.retrieveAPIKey()
            print("🔑 [OpenAIService] Retrieved API key from Keychain.")
        } catch {
            if let fallback = UserDefaults.standard.string(forKey: "openAIKey"),
               !fallback.isEmpty {
                apiKey = fallback
                print("🔑 [OpenAIService] Using API key from UserDefaults fallback.")
            } else {
                print("🔑 [OpenAIService] No API key found in Keychain or UserDefaults.")
                completion(.failure(APIError.noAPIKey))
                return
            }
        }

        // 2) Build request
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(APIError.invalidResponse))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_completion_tokens": maxTokens,
            "temperature": 0.7
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        // 3) Send with retry
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Log HTTP status and raw response
            if let httpRes = response as? HTTPURLResponse {
                print("🌐 [OpenAIService] HTTP status: \(httpRes.statusCode)")
            }
            if let data = data, let raw = String(data: data, encoding: .utf8) {
                print("🌐 [OpenAIService] Raw response body:\n\(raw)")
            }

            if let error = error as NSError?,
               error.domain == NSURLErrorDomain,
               error.code == NSURLErrorNetworkConnectionLost,
               retryCount < self.maxRetryAttempts {
                return self.generateChatTextInternal(prompt: prompt,
                                                     maxTokens: maxTokens,
                                                     retryCount: retryCount + 1,
                                                     completion: completion)
            } else if let error = error {
                return completion(.failure(error))
            }

            guard let data = data else {
                return completion(.failure(APIError.noData))
            }

            // 4) Parse and return
            do {
                guard
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let choices = json["choices"] as? [[String: Any]],
                    let first = choices.first,
                    let msg = first["message"] as? [String: Any],
                    let text = msg["content"] as? String
                else {
                    return completion(.failure(APIError.invalidResponse))
                }
                completion(.success(text))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: – Reciprocal Objections

    /// Ask the opposing counsel whether to object, stripping code fences.
    func requestObjectionResponse(question: String,
                                  completion: @escaping (Result<ObjectionResponse, Error>) -> Void) {
        let prompt = """
        You are opposing counsel in a US criminal courtroom. Under US Federal Rules of Evidence (relevance, hearsay, leading, argumentative, speculation), \
        evaluate this question for objection:

        Question: "\(question)"

        Respond ONLY with JSON EXACTLY one of:
        {"objection": true, "reason": "<legal ground>"}
        {"objection": false, "reason": null}
        """
        generateText(prompt: prompt) { result in
            switch result {
            case .success(let rawText):
                print("🔍 [Objection] Raw text:\n\(rawText)")
                // Remove code fences if present
                var cleaned = rawText
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                // Sometimes model includes surrounding quotes
                if cleaned.hasPrefix("\""), cleaned.hasSuffix("\"") {
                    cleaned = String(cleaned.dropFirst().dropLast())
                }
                print("🔍 [Objection] Cleaned JSON:\n\(cleaned)")
                guard let data = cleaned.data(using: .utf8) else {
                    completion(.failure(APIError.invalidResponse))
                    return
                }
                do {
                    let resp = try JSONDecoder().decode(ObjectionResponse.self, from: data)
                    print("🔍 [Objection] Parsed objection=\(resp.objection), reason=\(resp.reason ?? "nil")")
                    completion(.success(resp))
                } catch {
                    print("🔍 [Objection] JSON decode error: \(error)")
                    completion(.failure(error))
                }
            case .failure(let err):
                print("🔍 [Objection] Request error: \(err)")
                completion(.failure(err))
            }
        }
    }

    /// Ask the judge to rule, stripping code fences.
    func requestJudgeDecision(reason: String,
                              completion: @escaping (Result<JudgeDecision, Error>) -> Void) {
        let prompt = """
        You are the judge. Counsel objected on the following ground: "\(reason)". \
        Respond ONLY with JSON EXACTLY one of:
        {"decision": "sustain"}
        {"decision": "overrule"}
        """
        generateText(prompt: prompt) { result in
            switch result {
            case .success(let rawText):
                print("🔍 [Judge] Raw text:\n\(rawText)")
                var cleaned = rawText
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.hasPrefix("\""), cleaned.hasSuffix("\"") {
                    cleaned = String(cleaned.dropFirst().dropLast())
                }
                print("🔍 [Judge] Cleaned JSON:\n\(cleaned)")
                guard let data = cleaned.data(using: .utf8) else {
                    completion(.failure(APIError.invalidResponse))
                    return
                }
                do {
                    let resp = try JSONDecoder().decode(JudgeDecision.self, from: data)
                    print("🔍 [Judge] Parsed decision=\(resp.decision)")
                    completion(.success(resp))
                } catch {
                    print("🔍 [Judge] JSON decode error: \(error)")
                    completion(.failure(error))
                }
            case .failure(let err):
                print("🔍 [Judge] Request error: \(err)")
                completion(.failure(err))
            }
        }
    }

    // MARK: – Image Generation (unchanged)

    func generateImage(prompt: String,
                       completion: @escaping (Result<UIImage, Error>) -> Void) {
        // … existing implementation …
    }
}
