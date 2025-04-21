// CourtRoomSim/Services/OpenAIService.swift

import Foundation
import UIKit
import os

private let serviceLogger = Logger(subsystem: "com.pura.CourtRoomSim", category: "OpenAIService")

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

// Models for Reciprocal Objections
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

    // MARK: – Core Chat Call

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
        // Retrieve API key (Keychain first, then UserDefaults)
        let apiKey: String
        do {
            apiKey = try KeychainManager.shared.retrieveAPIKey()
            serviceLogger.debug("Retrieved API key from Keychain.")
        } catch {
            if let fallback = UserDefaults.standard.string(forKey: "openAIKey"),
               !fallback.isEmpty {
                apiKey = fallback
                serviceLogger.debug("Using API key from UserDefaults fallback.")
            } else {
                serviceLogger.error("No API key found in Keychain or UserDefaults.")
                completion(.failure(APIError.noAPIKey))
                return
            }
        }

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

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpRes = response as? HTTPURLResponse {
                serviceLogger.debug("HTTP status: \(httpRes.statusCode)")
            }
            if let raw = data.flatMap({ String(data: $0, encoding: .utf8) }) {
                serviceLogger.debug("Raw response body: \(raw)")
            }

            if let err = error as NSError?,
               err.domain == NSURLErrorDomain,
               err.code == NSURLErrorNetworkConnectionLost,
               retryCount < self.maxRetryAttempts {
                self.generateChatTextInternal(prompt: prompt,
                                              maxTokens: maxTokens,
                                              retryCount: retryCount + 1,
                                              completion: completion)
                return
            } else if let err = error {
                completion(.failure(err))
                return
            }

            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }

            do {
                guard
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let choices = json["choices"] as? [[String: Any]],
                    let first = choices.first,
                    let msg = first["message"] as? [String: Any],
                    let text = msg["content"] as? String
                else {
                    completion(.failure(APIError.invalidResponse))
                    return
                }
                completion(.success(text))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: – Reciprocal Objections

    func requestObjectionResponse(question: String,
                                  completion: @escaping (Result<ObjectionResponse, Error>) -> Void) {
        let prompt = """
        You are opposing counsel in a US criminal courtroom. Under US Federal Rules of Evidence (relevance, hearsay, leading, argumentative, speculation), evaluate this question for objection:

        Question: "\(question)"

        Respond ONLY with JSON EXACTLY one of:
        {"objection": true, "reason": "<legal ground>"}
        {"objection": false, "reason": null}
        """
        serviceLogger.debug("Objection prompt: \(prompt, privacy: .public)")
        generateText(prompt: prompt) { result in
            switch result {
            case .success(let rawText):
                serviceLogger.debug("Raw objection response: \(rawText, privacy: .public)")
                var cleaned = rawText
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.hasPrefix("\""), cleaned.hasSuffix("\"") {
                    cleaned = String(cleaned.dropFirst().dropLast())
                }
                serviceLogger.debug("Cleaned objection JSON: \(cleaned, privacy: .public)")
                guard let data = cleaned.data(using: .utf8) else {
                    completion(.failure(APIError.invalidResponse))
                    return
                }
                do {
                    let resp = try JSONDecoder().decode(ObjectionResponse.self, from: data)
                    serviceLogger.debug("Parsed objection=\(resp.objection), reason=\(resp.reason ?? "nil")")
                    completion(.success(resp))
                } catch {
                    serviceLogger.error("Objection JSON decode error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            case .failure(let err):
                serviceLogger.error("Objection request error: \(err.localizedDescription)")
                completion(.failure(err))
            }
        }
    }

    func requestJudgeDecision(reason: String,
                              completion: @escaping (Result<JudgeDecision, Error>) -> Void) {
        let prompt = """
        You are the judge. Counsel objected on the following ground: "\(reason)". Respond ONLY with JSON EXACTLY one of:
        {"decision": "sustain"}
        {"decision": "overrule"}
        """
        serviceLogger.debug("Judge prompt: \(prompt, privacy: .public)")
        generateText(prompt: prompt) { result in
            switch result {
            case .success(let rawText):
                serviceLogger.debug("Raw judge response: \(rawText, privacy: .public)")
                var cleaned = rawText
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.hasPrefix("\""), cleaned.hasSuffix("\"") {
                    cleaned = String(cleaned.dropFirst().dropLast())
                }
                serviceLogger.debug("Cleaned judge JSON: \(cleaned, privacy: .public)")
                guard let data = cleaned.data(using: .utf8) else {
                    completion(.failure(APIError.invalidResponse))
                    return
                }
                do {
                    let resp = try JSONDecoder().decode(JudgeDecision.self, from: data)
                    serviceLogger.debug("Parsed decision=\(resp.decision, privacy: .public)")
                    completion(.success(resp))
                } catch {
                    serviceLogger.error("Judge JSON decode error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            case .failure(let err):
                serviceLogger.error("Judge request error: \(err.localizedDescription)")
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
