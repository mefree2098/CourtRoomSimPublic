import SwiftUI

struct TrialView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var caseEntity: CaseEntity
    
    @State private var trialTranscript: String = ""
    @State private var isProcessing: Bool = false
    @State private var verdictText: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Trial Phase")
                .font(.largeTitle)
            ScrollView {
                Text(trialTranscript)
                    .padding()
            }
            if !verdictText.isEmpty {
                Text("Verdict: \(verdictText)")
                    .font(.headline)
                    .padding()
            }
            Button(action: {
                conductTrial()
            }) {
                if isProcessing {
                    ProgressView()
                } else {
                    Text("Proceed with Trial")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .navigationBarTitle("Trial", displayMode: .inline)
    }
    
    private func conductTrial() {
        isProcessing = true
        let prompt = """
        Simulate a complete trial proceeding for the given case. Include opening statements from prosecution and defense, witness testimonies, objections with judge rulings, closing statements, and a final unanimous jury deliberation resulting in a verdict ("Guilty" or "Not Guilty"). Return the full transcript along with the final verdict.
        """
        OpenAIService.shared.generateText(prompt: prompt) { result in
            DispatchQueue.main.async {
                self.isProcessing = false
                switch result {
                case .success(let transcript):
                    self.trialTranscript = transcript
                    self.parseVerdict(from: transcript)
                    self.saveTrialEvent(with: transcript)
                case .failure(let error):
                    self.trialTranscript = "Error during trial simulation: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func parseVerdict(from transcript: String) {
        // A simple check: if transcript contains "Guilty", set verdict to Guilty; otherwise Not Guilty.
        if transcript.contains("Guilty") {
            verdictText = "Guilty"
        } else {
            verdictText = "Not Guilty"
        }
        saveVerdict()
    }
    
    private func saveTrialEvent(with transcript: String) {
        let event = TrialEvent(context: viewContext)
        event.id = UUID()
        event.timestamp = Date()
        event.eventType = "Trial Transcript"
        event.summary = "Full trial transcript generated."
        event.details = transcript
        event.caseEntity = caseEntity
        do {
            try viewContext.save()
        } catch {
            print("Error saving trial event: \(error)")
        }
    }
    
    private func saveVerdict() {
        let verdict = Verdict(context: viewContext)
        verdict.id = UUID()
        verdict.isGuilty = (verdictText == "Guilty")
        verdict.juryDeliberation = trialTranscript // In a complete implementation, parse out detailed deliberation.
        verdict.caseEntity = caseEntity
        do {
            try viewContext.save()
        } catch {
            print("Error saving verdict: \(error)")
        }
    }
}

struct TrialView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleCase = CaseEntity(context: context)
        sampleCase.id = UUID()
        sampleCase.crimeType = "Theft"
        sampleCase.aiModel = "o3-mini"
        sampleCase.dateCreated = Date()
        return NavigationView {
            TrialView(caseEntity: sampleCase)
        }
        .environment(\.managedObjectContext, context)
    }
}
