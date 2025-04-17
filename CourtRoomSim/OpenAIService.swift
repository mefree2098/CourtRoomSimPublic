// OpenAIService.swift
// CourtRoomSim

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
        // 1) Retrieve API key
        let apiKey: String
        do {
            apiKey = try KeychainManager.shared.retrieveAPIKey()
        } catch {
            completion(.failure(APIError.noAPIKey))
            return
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
            // ← updated parameter name here:
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
            if let error = error as NSError? {
                if error.domain == NSURLErrorDomain,
                   error.code == NSURLErrorNetworkConnectionLost,
                   retryCount < self.maxRetryAttempts {
                    return self.generateChatTextInternal(prompt: prompt,
                                                         maxTokens: maxTokens,
                                                         retryCount: retryCount + 1,
                                                         completion: completion)
                }
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

    // MARK: – Image Generation (unchanged)

    func generateImage(prompt: String,
                       completion: @escaping (Result<UIImage, Error>) -> Void) {
        // … existing implementation doesn’t use max_tokens.
    }
}
