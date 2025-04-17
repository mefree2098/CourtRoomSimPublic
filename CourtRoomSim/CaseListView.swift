// CaseListView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct CaseListView: View {
    // MARK: – Core Data
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: CaseEntity.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \CaseEntity.crimeType, ascending: true)
        ]
    ) private var cases: FetchedResults<CaseEntity>

    // MARK: – Case creator VM
    @ObservedObject var viewModel: CaseCreatorViewModel

    // MARK: – UI State
    @State private var showRoleSheet = false
    @State private var showSettings = false

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
                // Settings button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                // New Case button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showRoleSheet = true
                    } label: {
                        Label("New Case", systemImage: "plus")
                    }
                }
            }
            // New Case sheet
            .sheet(isPresented: $showRoleSheet) {
                RoleAndModelSheet(viewModel: viewModel)
                    .environment(\.managedObjectContext, viewContext)
            }
            // Settings sheet
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        offsets.map { cases[$0] }.forEach(viewContext.delete)
        try? viewContext.save()
    }
}

struct CaseListView_Previews: PreviewProvider {
    static var previews: some View {
        let container = PersistenceController.shared.container
        CaseListView(viewModel: CaseCreatorViewModel())
            .environment(\.managedObjectContext, container.viewContext)
    }
}
