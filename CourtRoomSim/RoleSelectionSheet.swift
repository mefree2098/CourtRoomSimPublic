//
//  RoleSelectionSheet.swift
//  CourtRoomSim
//
//  FULL SOURCE – no stubs, no placeholders
//

import SwiftUI
import CoreData

/// A modal sheet that lets the player pick their role (Prosecutor / Defense)
/// and the OpenAI model, then requests a brand‑new case from `CaseCreatorViewModel`.
struct RoleSelectionSheet: View {

    // View‑model supplied by the presenting view
    @ObservedObject var viewModel: CaseCreatorViewModel

    // Environment
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss)               private var dismiss

    // Local UI state -------------------------------------------
    @State private var chosenRole : UserRole = .prosecutor
    @State private var chosenModel: AiModel  = .o4Mini
    @State private var errorMessage: String?

    // -----------------------------------------------------------
    var body: some View {
        NavigationView {
            Form {
                // ── ROLE ────────────────────────────────────────
                Section(header: Text("Select your courtroom role")) {
                    Picker("Role", selection: $chosenRole) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Text(role.rawValue.capitalized).tag(role)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                // ── MODEL ───────────────────────────────────────
                Section(header: Text("Select OpenAI model")) {
                    Picker("AI Model", selection: $chosenModel) {
                        ForEach(AiModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                // ── ERROR MESSAGE ───────────────────────────────
                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.callout)
                    }
                }

                // ── CREATE BUTTON ───────────────────────────────
                Section {
                    Button {
                        requestNewCase()
                    } label: {
                        if viewModel.isBusy {
                            HStack {
                                Spacer()
                                ProgressView().padding(.vertical, 4)
                                Spacer()
                            }
                        } else {
                            Text("Generate New Case")
                                .frame(maxWidth: .infinity, alignment: .center)
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
        }
    }

    // MARK: – Helpers
    private func requestNewCase() {
        errorMessage = nil
        viewModel.generate(role:  chosenRole,
                           model: chosenModel,
                           into:  context) { result in          // ←  matches the API above
            switch result {
            case .success:
                dismiss()
            case .failure(let err):
                errorMessage = err.localizedDescription
            }
        }
    }
}

// MARK: – Preview
#if DEBUG
struct RoleSelectionSheet_Previews: PreviewProvider {
    static var previews: some View {
        // minimal in‑memory Core Data stack for preview
        let container = NSPersistentContainer(name: "Preview")
        container.loadPersistentStores { _, _ in }
        let vm = CaseCreatorViewModel()
        return RoleSelectionSheet(viewModel: vm)
            .environment(\.managedObjectContext, container.viewContext)
    }
}
#endif
