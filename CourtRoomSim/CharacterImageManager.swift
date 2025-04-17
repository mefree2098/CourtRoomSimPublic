//
//  CharacterImageManager.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025-04-16.
//

import Foundation
import UIKit

class CharacterImageManager {
    
    static let shared = CharacterImageManager()
    private init() {}
    
    func generatePixelArtImage(prompt: String, apiKey: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let finalPrompt = prompt + ", pixel art with a retro 16-bit aesthetic"
        
        guard let url = URL(string: "https://api.openai.com/v1/images/generations") else {
            completion(.failure(NSError(domain: "Dalle", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "prompt": finalPrompt,
            "n": 1,
            "size": "512x512"
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let err = error {
                completion(.failure(err))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "Dalle", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                return
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                guard let arr = json?["data"] as? [[String: Any]],
                      let first = arr.first,
                      let urlString = first["url"] as? String,
                      let imageURL = URL(string: urlString)
                else {
                    throw NSError(domain: "Dalle", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])
                }
                let imageData = try Data(contentsOf: imageURL)
                completion(.success(imageData))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
