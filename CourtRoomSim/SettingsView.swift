// SettingsView.swift
// CourtRoomSim

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var profile = UserProfileManager.shared

    @State private var apiKey: String = ""
    @State private var isBusy: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section("My Profile") {
                    TextField("Your Name", text: $profile.playerName)
                        .autocapitalization(.words)
                    TextField("Description", text: $profile.playerDescription)

                    if let data = profile.playerImageData,
                       let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Text("No profile image")
                            .foregroundColor(.secondary)
                    }

                    Button {
                        guard !apiKey.isEmpty else {
                            alertMessage = "Set your API Key first."
                            showAlert = true
                            return
                        }
                        isBusy = true
                        profile.generateUserImage(apiKey: apiKey) { result in
                            isBusy = false
                            switch result {
                            case .success: break
                            case .failure(let err):
                                alertMessage = "Image generation failed:\n\(err.localizedDescription)"
                                showAlert = true
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isBusy { ProgressView() }
                            else { Text("Generate Avatar") }
                            Spacer()
                        }
                    }
                    .disabled(profile.playerName.trimmingCharacters(in: .whitespaces).isEmpty || isBusy)
                }

                Section("OpenAI Configuration") {
                    SecureField("OpenAI API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Button {
                        UserDefaults.standard.setValue(apiKey, forKey: "openAIKey")
                        alertMessage = "API Key saved."
                        showAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Save API Key")
                            Spacer()
                        }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Settings"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                apiKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
