//
//  AppState.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025-04-13.
//

import Foundation
import Combine

/// A simple ObservableObject to track global app state, such as onboarding progress.
class AppState: ObservableObject {
    
    /// Indicates whether the user has completed onboarding
    @Published var hasCompletedOnboarding: Bool = false
    
    // Add any other global flags or states here...
    
    init() {
        // Optionally read persistent storage if needed
    }
    
    func completeOnboarding() {
        // You could set a user default or something here if needed
        hasCompletedOnboarding = true
    }
}
