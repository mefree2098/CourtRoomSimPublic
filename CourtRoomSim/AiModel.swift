//
//  AiModel.swift
//  CourtRoomSim
//

import Foundation

/// All OpenAI chat‑models selectable by the user.
enum AiModel: String, CaseIterable, Identifiable {
    case o3Mini  = "o3-mini"       // legacy
    case o4Mini  = "o4-mini"       // ← NEW default model
    // add more cases here as needed.

    var id: String { rawValue }

    /// Human‑friendly label for UI.
    var displayName: String {
        switch self {
        case .o3Mini: return "o3‑mini"
        case .o4Mini: return "o4‑mini (new)"
        }
    }

    /// The default model to pre‑select.
    static let defaultModel: AiModel = .o4Mini
}
