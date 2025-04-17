import SwiftUI
import CoreData

struct PlayerProfileView: View {
    @State private var name: String = ""
    @State private var gender: String = "Male"   // Only "Male" and "Female"
    @State private var profileDescription: String = ""
    @State private var profileImage: UIImage? = nil
    @State private var isLoadingImage: Bool = false
    
    // Alert for OpenAI API errors (including safety violations).
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Name", text: $name)
                    
                    Picker("Gender", selection: $gender) {
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    TextField("Profile Description", text: $profileDescription)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section(header: Text("Profile Image")) {
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    } else if isLoadingImage {
                        ProgressView("Generating Profile Image...")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Button("Generate Profile Image") {
                            generateProfileImage()
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Player Profile")
            .navigationViewStyle(StackNavigationViewStyle())  // iPad & orientation support
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Image Generation Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    /// Generates a profile image using a safe, neutral prompt that is less likely to violate OpenAI’s content policy.
    private func generateProfileImage() {
        // Quick check to ensure user enters a name first.
        guard !name.isEmpty else {
            alertMessage = "Please enter a name before generating an image."
            showAlert = true
            return
        }
        
        isLoadingImage = true
        
        // Neutral prompt for an appropriate portrait.
        let prompt = """
            A professional, realistic portrait of \(name), a \(gender) individual, 
            in a neutral studio setting. The image should be suitable for a user profile. 
            Additional user-provided detail: \(profileDescription).
            """
        
        OpenAIService.shared.generateImage(prompt: prompt) { result in
            DispatchQueue.main.async {
                isLoadingImage = false
                switch result {
                case .success(let image):
                    profileImage = image
                case .failure(let error):
                    // Check for likely safety filter rejections or other errors.
                    let errorText = error.localizedDescription.lowercased()
                    if errorText.contains("content_policy_violation") || errorText.contains("safety") {
                        alertMessage = "OpenAI blocked this image prompt for safety reasons. Try adjusting your description."
                    } else {
                        alertMessage = "Image generation failed: \(error.localizedDescription)"
                    }
                    showAlert = true
                }
            }
        }
    }
}

struct PlayerProfileView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerProfileView()
    }
}
