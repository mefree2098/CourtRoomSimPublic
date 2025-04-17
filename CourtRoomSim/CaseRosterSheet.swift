//
//  CaseRosterSheet.swift
//  CourtRoomSim
//
//  Created by LeadDev on 2025‑05‑01.
//

import SwiftUI
import CoreData

/// A sheet that lists every participant—judge, counsel, witnesses, jury—in the case.
struct CaseRosterSheet: View {

    // MARK: – Dependencies
    @ObservedObject var caseEntity: CaseEntity
    @Environment(\.dismiss) private var dismiss

    // MARK: – Body
    var body: some View {
        NavigationView {
            List {
                rosterSection("Judge",              objects: [caseEntity.judge])
                rosterSection("Opposing Counsel",   objects: [caseEntity.opposingCounsel])
                rosterSection("Victim",             objects: [caseEntity.victim])
                rosterSection("Suspect",            objects: [caseEntity.suspect])
                rosterSetSection("Police",          set: caseEntity.police)
                rosterSetSection("Witnesses",       set: caseEntity.witnesses)
                rosterSetSection("Jury (\(juryCount))",
                                 set: caseEntity.jury)
            }
            .navigationTitle("Case Roster")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: – Helpers
    private var juryCount: Int {
        (caseEntity.jury as? Set<CourtCharacter>)?.count ?? 0
    }

    @ViewBuilder
    private func rosterSection(_ title: String,
                               objects: [CourtCharacter?]) -> some View {
        let items = objects.compactMap { $0 }
        if !items.isEmpty {
            Section(header: Text(title)) {
                ForEach(items, id: \.id) { CharacterRow(character: $0) }
            }
        }
    }

    @ViewBuilder
    private func rosterSetSection(_ title: String,
                                  set: NSSet?) -> some View {
        if let s = set as? Set<CourtCharacter>, !s.isEmpty {
            Section(header: Text(title)) {
                ForEach(Array(s), id: \.id) { CharacterRow(character: $0) }
            }
        }
    }
}

/// A single row showing a character’s avatar, name, and personality.
private struct CharacterRow: View {
    let character: CourtCharacter

    var body: some View {
        HStack {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(character.name ?? "—").font(.headline)
                if let p = character.personality {
                    Text(p).font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = character.imageData, let ui = UIImage(data: data) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("No\nImg")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                )
        }
    }
}
