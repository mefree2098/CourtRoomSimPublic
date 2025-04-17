//
//  CaseCreationPayload.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025-04-13.
//

import Foundation

/// (Optional) Not strictly used since we parse JSON manually.
struct CaseCreationPayload: Codable {
    let crimeType: String?
    let scenarioSummary: String?
    let victim: CharacterPayload?
    let suspect: CharacterPayload?
    let witnesses: [CharacterPayload]?
    let police: [CharacterPayload]?
    let trueGuiltyParty: CharacterPayload?
    let groundTruth: String?
    let privateInvestigator: CharacterPayload?
}
