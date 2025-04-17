//
//  CaseRole.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025-04-16.
//

import Foundation

/// The user can choose which role they play in the case
enum CaseRole: String, CaseIterable {
    case prosecutor = "Prosecutor"
    case defense = "Defense"
    
    static var allCases: [CaseRole] {
        return [.prosecutor, .defense]
    }
}
