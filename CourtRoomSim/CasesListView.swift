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
    @State private var showSettings = false
    @State private var showNotebook = false

    var body: some View {
        List {
            Section("Active Cases") {
                ForEach(activeCases) { c in
                    NavigationLink {
                        // Tapping a pre‑trial case still goes to CaseDetailView
                        if c.phase == CasePhase.preTrial.rawValue {
                            CaseDetailView(caseEntity: c)
                        }
                        // But any case already in trial/jury phase goes right into the flow
                        else {
                            TrialFlowView(caseEntity: c)
                        }
                    } label: {
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
                .onDelete(perform: deleteCases)
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Cases")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink("Dashboard") {
                    DashboardView()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                        .imageScale(.large)
                        .accessibilityLabel("Settings")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewCase = true
                } label: {
                    Label("New Case", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if let selectedCase = activeCases.first {
                    Button {
                        showNotebook = true
                    } label: {
                        Image(systemName: "book")
                            .imageScale(.large)
                            .accessibilityLabel("Notebook")
                    }
                }
            }
        }
        .sheet(isPresented: $showNewCase) {
            NewCaseView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showNotebook) {
            if let selectedCase = activeCases.first {
                NotebookView(caseEntity: selectedCase)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    private var activeCases: [CaseEntity] {
        allCases.filter { $0.phase != CasePhase.completed.rawValue }
    }

    private func deleteCases(at offsets: IndexSet) {
        let casesToDelete = offsets.map { activeCases[$0] }
        for c in casesToDelete {
            viewContext.delete(c)
        }
        do {
            try viewContext.save()
        } catch {
            print("Error deleting cases: \(error)")
        }
    }
} 