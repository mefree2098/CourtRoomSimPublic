// RoleAndModelSheet.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct RoleAndModelSheet: View {
    @ObservedObject var viewModel: CaseCreatorViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                // Role picker (no header, no inline label)
                Section {
                    Picker(selection: $viewModel.chosenRole) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Text(role.rawValue.capitalized).tag(role)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // Model picker (no header, no inline label)
                Section {
                    Picker(selection: $viewModel.chosenModel) {
                        ForEach(AiModel.allCases, id: \.self) { model in
                            Text(model.displayName).tag(model)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
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
        }
    }

    private func createCase() {
        viewModel.generate(
            role: viewModel.chosenRole,
            model: viewModel.chosenModel,
            into: viewContext
        ) { _ in
            dismiss()
        }
    }
}
