//
//  UserProfileManager.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025-04-15.
//

import Foundation
import SwiftUI

class UserProfileManager: ObservableObject {
    static let shared = UserProfileManager()
    
    @Published var playerName: String
    @Published var playerDescription: String
    @Published var playerImageData: Data?
    
    private let nameKey = "playerNameKey"
    private let descKey = "playerDescKey"
    private let imageKey = "playerImageKey"
    
    private init() {
        let defaults = UserDefaults.standard
        self.playerName = defaults.string(forKey: nameKey) ?? ""
        self.playerDescription = defaults.string(forKey: descKey) ?? ""
        self.playerImageData = defaults.data(forKey: imageKey)
    }
    
    func saveProfile() {
        let defaults = UserDefaults.standard
        defaults.setValue(playerName, forKey: nameKey)
        defaults.setValue(playerDescription, forKey: descKey)
        defaults.setValue(playerImageData, forKey: imageKey)
    }
    
    func generateUserImage(apiKey: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let basePrompt = "A portrait of \(playerName). Description: \(playerDescription)"
        CharacterImageManager.shared.generatePixelArtImage(prompt: basePrompt, apiKey: apiKey) { result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    self.playerImageData = data
                    self.saveProfile()
                }
                completion(.success(data))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }
    
    func needsSetup() -> Bool {
        return playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
