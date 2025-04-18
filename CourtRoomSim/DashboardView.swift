// DashboardView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: CaseEntity.entity(),
        sortDescriptors: [NSSortDescriptor(key: "id", ascending: false)]
    ) private var cases: FetchedResults<CaseEntity>

    var body: some View {
        List {
            Section("All Cases") {
                ForEach(cases) { c in
                    NavigationLink(destination: ReadOnlyCaseDetailView(caseEntity: c)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(c.crimeType ?? "Untitled Case")
                                .font(.headline)
                            HStack {
                                Text("Phase: \(c.phase ?? "")")
                                Spacer()
                                Text("Role: \(c.userRole ?? "")")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            HStack {
                                Text("Model: \(c.aiModel ?? "")")
                                Spacer()
                                if c.phase == CasePhase.completed.rawValue {
                                    Text(userOutcome(for: c))
                                    Text("Justice: \(justiceServedText(for: c))")
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Dashboard")
    }

    private func userOutcome(for c: CaseEntity) -> String {
        guard let verdict = c.verdict else { return "Outcome: N/A" }
        let isProsecutor = (c.userRole ?? "").lowercased().contains("prosecutor")
        let won = (isProsecutor && verdict == "Guilty")
               || (!isProsecutor && verdict == "Not Guilty")
        return won ? "Outcome: Won" : "Outcome: Lost"
    }

    private func justiceServedText(for c: CaseEntity) -> String {
        guard let verdict = c.verdict else { return "No" }
        let suspectGuilty = c.groundTruth
        if verdict == "Guilty" && suspectGuilty { return "Yes" }
        if verdict == "Not Guilty" && !suspectGuilty { return "Yes" }
        return "No"
    }
}
