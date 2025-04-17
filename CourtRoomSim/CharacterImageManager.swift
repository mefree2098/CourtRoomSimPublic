// CharacterImageManager.swift
// CourtRoomSim

import Foundation

/// Errors specific to character image generation.
enum CharacterImageError: Error, LocalizedError {
    case invalidURL
    case noData
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Failed to construct the image generation URL."
        case .noData:
            return "No data was returned from the server."
        case .invalidResponse:
            return "The server response was malformed or missing expected fields."
        }
    }
}

/// Codable request payload for OpenAI Images API.
private struct OpenAIImageRequest: Codable {
    let prompt: String
    let n: Int
    let size: String
    let response_format: String
}

/// Codable response payload for OpenAI Images API.
private struct OpenAIImageResponse: Codable {
    struct ImageData: Codable {
        let url: String
    }
    let created: Int
    let data: [ImageData]
}

/// Responsible for generating character portrait images via OpenAI's Images API.
final class CharacterImageManager {
    static let shared = CharacterImageManager()
    private init() {}

    /// Generates a single 512×512 image from the given prompt.
    /// - Parameters:
    ///   - prompt: The text prompt for image generation.
    ///   - apiKey: Your OpenAI API key.
    ///   - completion: Called on the main thread with the resulting Data or an Error.
    func generatePixelArtImage(prompt: String,
                                apiKey: String,
                                completion: @escaping (Result<Data, Error>) -> Void) {
        // 1) Build the generation request URL
        guard let url = URL(string: "https://api.openai.com/v1/images/generations") else {
            DispatchQueue.main.async {
                completion(.failure(CharacterImageError.invalidURL))
            }
            return
        }

        // 2) Configure the URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = OpenAIImageRequest(
            prompt: prompt,
            n: 1,
            size: "512x512",
            response_format: "url"
        )
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
            return
        }

        // 3) Send the generation request
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(CharacterImageError.noData))
                }
                return
            }

            // 4) Decode the JSON to extract the image URL
            do {
                let imageResponse = try JSONDecoder().decode(OpenAIImageResponse.self, from: data)
                guard
                    let urlString = imageResponse.data.first?.url,
                    let imageURL = URL(string: urlString)
                else {
                    DispatchQueue.main.async {
                        completion(.failure(CharacterImageError.invalidResponse))
                    }
                    return
                }

                // 5) Download the image bytes
                URLSession.shared.dataTask(with: imageURL) { imgData, _, imgError in
                    if let imgError = imgError {
                        DispatchQueue.main.async {
                            completion(.failure(imgError))
                        }
                        return
                    }
                    guard let imgData = imgData else {
                        DispatchQueue.main.async {
                            completion(.failure(CharacterImageError.noData))
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        completion(.success(imgData))
                    }
                }.resume()

            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
