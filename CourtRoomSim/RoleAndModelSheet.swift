// RoleAndModelSheet.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct RoleAndModelSheet: View {
    @ObservedObject var viewModel: CaseCreatorViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // MARK: – Error state
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            Form {
                // Role picker
                Section(header: Text("Select your role")) {
                    Picker("Role", selection: $viewModel.chosenRole) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Text(role.rawValue.capitalized).tag(role)
                        }
                    }
                    .pickerStyle(.inline)
                }

                // Model picker
                Section(header: Text("Select AI model")) {
                    Picker("Model", selection: $viewModel.chosenModel) {
                        ForEach(AiModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.inline)
                }

                // Create Case button
                Section {
                    Button {
                        createCase()
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isBusy {
                                ProgressView()
                            } else {
                                Text("Create Case")
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isBusy)
                }
            }
            .navigationTitle("New Case")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Alert on error
            .alert("Error Creating Case", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func createCase() {
        viewModel.generate(
            role: viewModel.chosenRole,
            model: viewModel.chosenModel,
            into: viewContext
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    dismiss()
                case .failure(let err):
                    // Show alert and log to console
                    errorMessage = err.localizedDescription
                    showErrorAlert = true
                    print("❌ Failed to create case:", err)
                }
            }
        }
    }
}

struct RoleAndModelSheet_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        RoleAndModelSheet(viewModel: CaseCreatorViewModel())
            .environment(\.managedObjectContext, container.viewContext)
    }
}
