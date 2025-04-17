//
//  UserRole.swift
//  CourtRoomSim
//
//  Created 2025‑05‑03
//

import Foundation

/// All roles the player may assume when a case is generated.
enum UserRole: String, CaseIterable, Identifiable {

    case prosecutor = "Prosecutor"
    case defense    = "Defense"

    /// Conformance needed for SwiftUI `Picker` / `ForEach`.
    var id: String { rawValue }

    /// Read‑friendly label used in UI lists.
    var displayName: String { rawValue }

    /// The opposing counsel’s role, useful throughout the trial flow.
    var opposite: UserRole {
        switch self {
        case .prosecutor: return .defense
        case .defense:    return .prosecutor
        }
    }
}
