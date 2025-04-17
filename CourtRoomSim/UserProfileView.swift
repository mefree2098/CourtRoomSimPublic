//
//  UserProfileView.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025-04-15.
//

import SwiftUI

struct UserProfileView: View {
    
    @ObservedObject var profileManager = UserProfileManager.shared
    @Environment(\.presentationMode) private var presentationMode
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("Your Name", text: $profileManager.playerName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.top, 20)
                
                TextField("Short Description", text: $profileManager.playerDescription)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if let data = profileManager.playerImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 180, height: 180)
                        .overlay(Text("No Image").font(.caption))
                }
                
                if let err = errorMessage {
                    Text("Error: \(err)")
                        .foregroundColor(.red)
                }
                
                if isGenerating {
                    ProgressView("Generating Image...")
                        .padding(.bottom, 8)
                }
                
                HStack(spacing: 20) {
                    Button("Regenerate Image") {
                        regenerateImage()
                    }
                    .disabled(profileManager.playerName.isEmpty || profileManager.playerDescription.isEmpty)
                    
                    Button("Save & Close") {
                        profileManager.saveProfile()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .padding(.top, 8)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("Your Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func regenerateImage() {
        guard let apiKey = UserDefaults.standard.string(forKey: "openAIKey"), !apiKey.isEmpty else {
            self.errorMessage = "No OpenAI API key found in Settings."
            return
        }
        if profileManager.playerName.isEmpty || profileManager.playerDescription.isEmpty {
            self.errorMessage = "Please fill in name & description first."
            return
        }
        isGenerating = true
        errorMessage = nil
        
        profileManager.generateUserImage(apiKey: apiKey) { result in
            DispatchQueue.main.async {
                self.isGenerating = false
            }
            switch result {
            case .success(_):
                break
            case .failure(let err):
                DispatchQueue.main.async {
                    self.errorMessage = "Image gen failed: \(err)"
                }
            }
        }
    }
}
