// CasesListView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct CasesListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: CaseEntity.entity(),
        sortDescriptors: [NSSortDescriptor(key: "id", ascending: false)]
    ) private var allCases: FetchedResults<CaseEntity>

    @State private var showNewCase = false

    var body: some View {
        List {
            Section("Active Cases") {
                ForEach(activeCases) { c in
                    NavigationLink(destination: CaseDetailView(caseEntity: c)) {
                        VStack(alignment: .leading) {
                            Text(c.crimeType ?? "Untitled Case")
                                .font(.headline)
                            Text("Phase: \(c.phase ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Cases")
        .toolbar {
            // Dashboard button
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink("Dashboard") {
                    DashboardView()
                }
            }
            // Settings gear icon
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gear")
                        .imageScale(.large)
                        .accessibility(label: Text("Settings"))
                }
            }
            // New Case button as modal
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showNewCase = true }) {
                    Label("New Case", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewCase) {
            NewCaseView()
                .environment(\.managedObjectContext, viewContext)
        }
    }

    private var activeCases: [CaseEntity] {
        allCases.filter { $0.phase != CasePhase.completed.rawValue }
    }
}

// Preview
struct CasesListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CasesListView()
                .environment(\.managedObjectContext,
                              PersistenceController.shared.container.viewContext)
        }
    }
}
