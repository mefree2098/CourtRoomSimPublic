// CaseRosterSheet.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct CaseRosterSheet: View {
    @ObservedObject var caseEntity: CaseEntity
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            rosterSection("Judge", [caseEntity.judge])
            rosterSection("Opposing Counsel", [caseEntity.opposingCounsel])
            rosterSection("Victim", [caseEntity.victim])
            rosterSection("Suspect", [caseEntity.suspect])
            rosterSetSection("Police", set: caseEntity.police)
            rosterSetSection("Witnesses", set: caseEntity.witnesses)
            rosterSetSection("Jury (\(juryCount))", set: caseEntity.jury)
        }
        .navigationTitle("Case Roster")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var juryCount: Int {
        (caseEntity.jury as? Set<CourtCharacter>)?.count ?? 0
    }

    private func rosterSection(
        _ title: String,
        _ objects: [CourtCharacter?]
    ) -> some View {
        let items = objects.compactMap { $0 }
        return Section(header: Text(title)) {
            ForEach(items, id: \.id) { c in
                NavigationLink(destination:
                    CharacterTranscriptView(caseEntity: caseEntity, character: c)
                ) {
                    CharacterRow(character: c)
                }
            }
        }
    }

    private func rosterSetSection(
        _ title: String,
        set: NSSet?
    ) -> some View {
        guard let s = set as? Set<CourtCharacter>, !s.isEmpty else {
            return AnyView(EmptyView())
        }
        return AnyView(
            Section(header: Text(title)) {
                ForEach(Array(s), id: \.id) { c in
                    NavigationLink(destination:
                        CharacterTranscriptView(caseEntity: caseEntity, character: c)
                    ) {
                        CharacterRow(character: c)
                    }
                }
            }
        )
    }
}

private struct CharacterRow: View {
    let character: CourtCharacter
    var body: some View {
        HStack {
            if let data = character.imageData,
               let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(Text("No\nImg")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(character.name ?? "—").font(.headline)
                if let p = character.personality {
                    Text(p).font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }
}
