// NewCaseView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct NewCaseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRole: UserRole = .prosecutor
    @State private var selectedModel: AiModel = .o4Mini
    @State private var isGenerating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Role")) {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Text(role.rawValue.capitalized).tag(role)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("AI Model")) {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(AiModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section {
                    Button(action: createCase) {
                        HStack {
                            Spacer()
                            if isGenerating {
                                ProgressView()
                            } else {
                                Text("Create Case")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isGenerating)
                }
            }
            .navigationTitle("New Case")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func createCase() {
        isGenerating = true
        errorMessage = nil

        let manager = CaseGenerationManager()
        manager.generate(
            into: viewContext,
            role: selectedRole,
            model: selectedModel
        ) { result in
            DispatchQueue.main.async {
                isGenerating = false
                switch result {
                case .success:
                    // Dismiss back to the cases list
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: – Preview

struct NewCaseView_Previews: PreviewProvider {
    static var previews: some View {
        NewCaseView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
