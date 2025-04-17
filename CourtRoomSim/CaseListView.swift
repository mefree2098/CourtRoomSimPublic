//
//  CaseListView.swift
//  CourtRoomSim
//
//  Lists all saved cases and lets the user create a new one.
//

import SwiftUI
import CoreData

struct CaseListView: View {

    // Core Data
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: CaseEntity.entity(),
        sortDescriptors: [           // sort by crimeType (guaranteed attribute)
            NSSortDescriptor(keyPath: \CaseEntity.crimeType, ascending: true)
        ]
    ) private var cases: FetchedResults<CaseEntity>

    // new‑case creator VM (injected from root)
    @ObservedObject var viewModel: CaseCreatorViewModel

    // UI
    @State private var showRoleSheet = false

    var body: some View {
        NavigationView {
            List {
                ForEach(cases) { c in
                    NavigationLink(destination: CaseDetailView(caseEntity: c)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.crimeType ?? "Unknown Crime")
                                .font(.headline)
                            Text(c.details ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("My Cases")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showRoleSheet = true
                    } label: {
                        Label("New Case", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showRoleSheet) {
                RoleAndModelSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: – delete helper
    private func delete(_ offsets: IndexSet) {
        offsets.map { cases[$0] }.forEach(viewContext.delete)
        try? viewContext.save()
    }
}
