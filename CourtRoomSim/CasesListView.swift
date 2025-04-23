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
            Section {
                ForEach(activeCases) { c in
                    NavigationLink {
                        if c.phase == CasePhase.preTrial.rawValue {
                            CaseDetailView(caseEntity: c)
                        } else {
                            TrialFlowView(caseEntity: c)
                        }
                    } label: {
                        CaseRowView(caseEntity: c)
                    }
                }
                .onDelete(perform: deleteCases)
            } header: {
                Text("Active Cases")
                    .textCase(.uppercase)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Cases")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink {
                    DashboardView()
                } label: {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let selectedCase = activeCases.first {
                    Button {
                        showNotebook = true
                    } label: {
                        Label("Notebook", systemImage: "book")
                    }
                    .help("Open case notebook")
                }
                
                Button {
                    showNewCase = true
                } label: {
                    Label("New Case", systemImage: "plus")
                }
                .help("Create a new case")
                
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .help("Open settings")
            }
        }
        .sheet(isPresented: $showNewCase) {
            NavigationView {
                NewCaseView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                SettingsView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(isPresented: $showNotebook) {
            if let selectedCase = activeCases.first {
                NavigationView {
                    NotebookView(caseEntity: selectedCase)
                        .environment(\.managedObjectContext, viewContext)
                }
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

struct CaseRowView: View {
    let caseEntity: CaseEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(caseEntity.crimeType ?? "Untitled Case")
                    .font(.headline)
                Spacer()
                PhaseBadge(phase: caseEntity.phase ?? "")
            }
            
            if let details = caseEntity.details, !details.isEmpty {
                Text(details)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PhaseBadge: View {
    let phase: String
    
    var body: some View {
        Text(phase)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        switch phase {
        case CasePhase.preTrial.rawValue:
            return .blue
        case CasePhase.trial.rawValue:
            return .orange
        case CasePhase.juryDeliberation.rawValue:
            return .purple
        case CasePhase.completed.rawValue:
            return .gray
        default:
            return .secondary
        }
    }
} 