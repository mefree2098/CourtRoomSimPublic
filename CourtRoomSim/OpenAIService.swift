import Foundation
import UIKit

enum APIError: Error {
    case noData
    case invalidResponse
    case noAPIKey
}

/// This service uses the Chat Completions API endpoint for text and the official image-generation endpoint.
final class OpenAIService {
    static let shared = OpenAIService()
    private init() {}
    
    private let maxRetryAttempts = 2
    
    // MARK: - Chat-based Text Generation API Call with Enhanced Logging
    /// Generates text using the Chat Completions API.
    /// - Parameters:
    ///   - prompt: The prompt to send.
    ///   - maxTokens: Maximum number of tokens to generate.
    ///   - completion: Completion handler with the generated text.
    func generateText(prompt: String, maxTokens: Int = 300, completion: @escaping (Result<String, Error>) -> Void) {
        generateChatTextInternal(prompt: prompt, maxTokens: maxTokens, retryCount: 0, completion: completion)
    }
    
    private func generateChatTextInternal(prompt: String, maxTokens: Int, retryCount: Int, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = KeychainManager.shared.getAPIKey() else {
            completion(.failure(APIError.noAPIKey))
            return
        }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Force connection close to avoid persistent connection issues.
        request.setValue("close", forHTTPHeaderField: "Connection")
        
        // Wrap the prompt as a user message.
        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": maxTokens,
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("JSON serialization error: \(error)")
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error as NSError? {
                print("Data task error: \(error) - \(error.localizedDescription)")
                if let underlyingError = error.userInfo[NSUnderlyingErrorKey] {
                    print("Underlying error: \(underlyingError)")
                }
                if error.domain == NSURLErrorDomain && error.code == -1005, retryCount < self.maxRetryAttempts {
                    print("Retrying due to network error (-1005): attempt \(retryCount + 1)")
                    self.generateChatTextInternal(prompt: prompt, maxTokens: maxTokens, retryCount: retryCount + 1, completion: completion)
                    return
                }
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP Status Code: \(httpResponse.statusCode)")
                print("Response Headers: \(httpResponse.allHeaderFields)")
            }
            
            if let data = data, let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw Response Data: \(rawResponse)")
            } else {
                print("No response data received.")
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let messageDict = firstChoice["message"] as? [String: Any],
                      let generatedText = messageDict["content"] as? String
                else {
                    print("Invalid response format: \(String(data: data, encoding: .utf8) ?? "n/a")")
                    completion(.failure(APIError.invalidResponse))
                    return
                }
                print("Generated text: \(generatedText)")
                completion(.success(generatedText))
            } catch {
                print("JSON parsing error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - DALL·E Image Generation API Call Using Official Endpoint
    func generateImage(prompt: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard let apiKey = KeychainManager.shared.getAPIKey() else {
            completion(.failure(APIError.noAPIKey))
            return
        }
        // Use the official DALL·E image generation endpoint.
        let url = URL(string: "https://api.openai.com/v1/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("close", forHTTPHeaderField: "Connection")
        
        let body: [String: Any] = [
            "prompt": prompt,
            "n": 1,
            "size": "512x512"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Image request JSON error: \(error)")
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Image generation request error: \(error)")
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("Image HTTP Status Code: \(httpResponse.statusCode)")
                print("Image Response Headers: \(httpResponse.allHeaderFields)")
            }
            guard let data = data else {
                print("No data received for image generation.")
                completion(.failure(APIError.noData))
                return
            }
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataArray = json["data"] as? [[String: Any]],
                      let firstResult = dataArray.first,
                      let imageUrlString = firstResult["url"] as? String,
                      let imageUrl = URL(string: imageUrlString)
                else {
                    print("Invalid image response format: \(String(data: data, encoding: .utf8) ?? "n/a")")
                    completion(.failure(APIError.invalidResponse))
                    return
                }
                // Download the image from the returned URL.
                URLSession.shared.dataTask(with: imageUrl) { imageData, _, imageError in
                    if let imageError = imageError {
                        print("Image download error: \(imageError)")
                        completion(.failure(imageError))
                        return
                    }
                    guard let imageData = imageData, let image = UIImage(data: imageData) else {
                        print("Failed to create image from downloaded data.")
                        completion(.failure(APIError.noData))
                        return
                    }
                    completion(.success(image))
                }.resume()
            } catch {
                print("JSON parsing error for image generation: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
}
