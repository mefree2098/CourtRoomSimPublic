import SwiftUI

struct CaseCreationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode

    @State private var crimeType: String = ""
    @State private var userRole: String = "Prosecutor"
    let roles = ["Prosecutor", "Defense"]

    @State private var aiModel: String = "o3-mini"
    let aiModels = ["gpt-4o", "o3-mini"]

    @State private var isGenerating: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                Text("New Case Setup")
                    .font(.title)
                
                TextField("Type of Crime (e.g., theft, murder)", text: $crimeType)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Picker("Select Role", selection: $userRole) {
                    ForEach(roles, id: \.self) { role in
                        Text(role)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                Picker("AI Model", selection: $aiModel) {
                    ForEach(aiModels, id: \.self) { model in
                        Text(model)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                Button(action: generateCaseScenario) {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Text("Generate Case")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
            }
            
            if isGenerating {
                Color.black.opacity(0.2)
                    .edgesIgnoringSafeArea(.all)
                VStack {
                    ProgressView("Generating case...")
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
        }
        .navigationBarTitle("Create Case", displayMode: .inline)
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func generateCaseScenario() {
        guard !crimeType.isEmpty else {
            errorMessage = "Please enter a crime type."
            return
        }
        isGenerating = true
        errorMessage = ""
        
        // Prompt that asks for creative names, deep backstories, etc.
        let prompt = """
        Generate a valid JSON object representing a detailed case scenario for a \(crimeType) case.
        The user is playing the role of \(userRole). The JSON MUST have exactly the following structure, with no extra keys or markdown:

        {
          "crimeType": "<string>",
          "victim": {
            "name": "<creative name>",
            "description": "<brief desc>",
            "background": "<detailed background>",
            "imagePrompt": "<portrait prompt>"
          },
          "suspect": {
            "name": "<creative name>",
            "description": "<desc>",
            "background": "<background>",
            "imagePrompt": "<portrait prompt>"
          },
          "witnesses": [
            {
              "name": "<creative name>",
              "description": "<desc>",
              "background": "<background>",
              "imagePrompt": "<portrait prompt>"
            }
          ],
          "police": [
            {
              "name": "<creative name>",
              "description": "<desc>",
              "background": "<background>",
              "imagePrompt": "<portrait prompt>"
            }
          ],
          "privateInvestigator": {
            "name": "<creative name>",
            "description": "<desc>",
            "background": "<background>",
            "clues": "<clues>",
            "imagePrompt": "<portrait prompt>"
          },
          "trueGuiltyParty": {
            "name": "<creative name>",
            "description": "<desc>",
            "background": "<background>",
            "imagePrompt": "<portrait prompt>"
          },
          "groundTruth": "<guilty or innocent>"
        }

        Names must be very creative, no placeholders like 'John Doe'. Include deep backstories/personalities. No markdown or triple backticks in output, only raw JSON.
        """
        
        OpenAIService.shared.generateText(prompt: prompt, maxTokens: 3000) { result in
            DispatchQueue.main.async {
                self.isGenerating = false
                switch result {
                case .success(let text):
                    var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Remove triple backticks if present.
                    if cleaned.hasPrefix("```") {
                        cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
                        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
                    }
                    self.saveCase(with: cleaned)
                    
                case .failure(let error):
                    self.errorMessage = "Failed to generate case: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func saveCase(with scenario: String) {
        let newCase = CaseEntity(context: viewContext)
        newCase.id = UUID()
        newCase.crimeType = crimeType
        newCase.aiModel = aiModel
        newCase.dateCreated = Date()
        newCase.details = scenario
        
        let event = TrialEvent(context: viewContext)
        event.id = UUID()
        event.timestamp = Date()
        event.eventType = "Case Generation"
        event.summary = "Detailed case scenario generated."
        event.details = scenario
        event.caseEntity = newCase
        
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            self.errorMessage = "Failed to save new case: \(error.localizedDescription)"
        }
    }
}

struct CaseCreationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CaseCreationView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        }
    }
}
