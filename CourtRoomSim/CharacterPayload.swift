//
//  CharacterPayload.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025-04-13.
//

import Foundation

/// (Optional) for reference
struct CharacterPayload: Codable {
    let name: String?
    let description: String?
    let background: String?
    let motivation: String?
    let imagePrompt: String?
}
