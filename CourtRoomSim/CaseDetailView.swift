// CaseDetailView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct CaseDetailView: View {
    @ObservedObject var caseEntity: CaseEntity
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showTrialSheet = false
    @State private var showNotebook = false
    @State private var selectedChatCharacter: CourtCharacter? = nil

    private var isMurder: Bool {
        (caseEntity.crimeType ?? "").lowercased().contains("murder")
    }

    var body: some View {
        Form {
            // Case summary
            Section(header: Text("Case")) {
                Text(caseEntity.crimeType ?? "Unknown Crime")
                    .font(.headline)
                Text(caseEntity.details ?? "")
                    .font(.subheadline)
            }

            // Victim
            Section(header: Text("Victim")) {
                if let v = caseEntity.victim {
                    if isMurder {
                        HStack {
                            Text("Victim (deceased)")
                            Spacer()
                            Text(v.name ?? "")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Victim")
                            Spacer()
                            Text(v.name ?? "")
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedChatCharacter = v
                        }
                    }
                }
            }

            // Suspect
            Section(header: Text("Suspect")) {
                if let s = caseEntity.suspect {
                    HStack {
                        Text("Suspect")
                        Spacer()
                        Text(s.name ?? "")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedChatCharacter = s
                    }
                }
            }

            // Witnesses
            Section(header: Text("Witnesses")) {
                ForEach(Array((caseEntity.witnesses as? Set<CourtCharacter>) ?? [])) { w in
                    HStack {
                        Text("Witness")
                        Spacer()
                        Text(w.name ?? "")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedChatCharacter = w
                    }
                }
            }

            // Police
            Section(header: Text("Police")) {
                ForEach(Array((caseEntity.police as? Set<CourtCharacter>) ?? [])) { p in
                    HStack {
                        Text("Police")
                        Spacer()
                        Text(p.name ?? "")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedChatCharacter = p
                    }
                }
            }

            // Opposing Counsel
            Section(header: Text("Opposing Counsel")) {
                if let opp = caseEntity.opposingCounsel {
                    HStack {
                        Text(opp.role ?? "Counsel")
                        Spacer()
                        Text(opp.name ?? "")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedChatCharacter = opp
                    }
                }
            }

            // Judge
            Section(header: Text("Judge")) {
                if let j = caseEntity.judge {
                    HStack {
                        Text("Judge")
                        Spacer()
                        Text(j.name ?? "")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedChatCharacter = j
                    }
                }
            }

            // Proceed to Trial
            if caseEntity.phase == CasePhase.preTrial.rawValue {
                Section {
                    Button("Proceed to Trial") {
                        showTrialSheet = true
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Case Roster")
        .toolbar {
            // Close button if presented as sheet
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            // Notebook button
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showNotebook = true }) {
                    Image(systemName: "book")
                        .imageScale(.large)
                        .accessibility(label: Text("Notebook"))
                }
            }
        }
        .sheet(isPresented: $showTrialSheet) {
            TrialFlowView(caseEntity: caseEntity)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showNotebook) {
            NotebookView(caseEntity: caseEntity)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(item: $selectedChatCharacter) { character in
    CharacterChatView(caseEntity: caseEntity, character: character)
        .environment(\.managedObjectContext, viewContext)
}
    }
}
