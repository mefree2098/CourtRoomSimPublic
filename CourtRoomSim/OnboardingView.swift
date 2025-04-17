//
//  OnboardingView.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025-04-13.
//

import SwiftUI

struct OnboardingView: View {
    
    /// We observe the global AppState so we can mark onboarding as complete.
    @ObservedObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to CourtRoomSim!")
                .font(.largeTitle)
                .padding(.top, 40)
            
            Text("This brief onboarding will guide you through setup.")
                .font(.title3)
                .padding(.horizontal)
            
            Spacer()
            
            // Add any onboarding pages / tutorial steps here...
            
            Button(action: finishOnboarding) {
                Text("Finish Onboarding")
                    .font(.headline)
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.bottom, 40)
        }
    }
    
    private func finishOnboarding() {
        // Mark onboarding as complete
        appState.completeOnboarding()
        
        // If you navigate away, do so here, e.g.:
        // appState.hasCompletedOnboarding = true
        // or any other navigation logic
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        // Use a sample AppState
        OnboardingView(appState: AppState())
    }
}
