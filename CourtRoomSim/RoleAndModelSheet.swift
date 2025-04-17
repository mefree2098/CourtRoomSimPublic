//  RoleAndModelSheet.swift
//  CourtRoomSim
//
//  Presents two pickers—Role and Model—then creates a new case
//  through CaseCreatorViewModel.generate(_:model:into:completion:)
//

import SwiftUI
import CoreData

struct RoleAndModelSheet: View {

    // view‑model supplied by the presenting view
    @ObservedObject var viewModel: CaseCreatorViewModel

    // Core‑Data context needed for persist‑ing the new case
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // ── Role picker ───────────────────────────────────────────
                Section(header: Text("Select your role")) {
                    Picker("Role", selection: $viewModel.chosenRole) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Text(role.rawValue.capitalized).tag(role)
                        }
                    }
                    .pickerStyle(.inline)
                }

                // ── Model picker ──────────────────────────────────────────
                Section(header: Text("Select AI model")) {
                    Picker("Model", selection: $viewModel.chosenModel) {
                        ForEach(AiModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    .pickerStyle(.inline)
                }

                // ── Generate button ───────────────────────────────────────
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
        }
    }

    // ------------------------------------------------------------------
    private func createCase() {
        viewModel.generate(role:  viewModel.chosenRole,
                           model: viewModel.chosenModel,
                           into:  viewContext) { _ in
            // We don’t need the result here; CaseListView listens for changes
            dismiss()
        }
    }
}

// ----------------------------------------------------------------------
// Preview
// ----------------------------------------------------------------------

#if DEBUG
struct RoleAndModelSheet_Previews: PreviewProvider {
    static var previews: some View {
        // Mock in‑memory Core‑Data stack for the preview
        let container = NSPersistentContainer(name: "CourtRoomSim")
        container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores(completionHandler: { _, _ in })

        return RoleAndModelSheet(
            viewModel: CaseCreatorViewModel()
        )
        .environment(\.managedObjectContext, container.viewContext)
    }
}
#endif
