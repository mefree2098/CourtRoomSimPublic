// CharacterTranscriptView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct CharacterTranscriptView: View {
    @ObservedObject var caseEntity: CaseEntity
    let character: CourtCharacter

    @FetchRequest private var messages: FetchedResults<Conversation>

    init(caseEntity: CaseEntity, character: CourtCharacter) {
        self.caseEntity = caseEntity
        self.character = character

        let req = NSFetchRequest<Conversation>(entityName: "Conversation")
        req.predicate = NSPredicate(
            format: "caseEntity == %@ AND sender == %@",
            caseEntity,
            character.name ?? ""
        )
        req.sortDescriptors = [
            NSSortDescriptor(key: "timestamp", ascending: true)
        ]
        _messages = FetchRequest(fetchRequest: req)
    }

    var body: some View {
        List(messages, id: \.self) { msg in
            VStack(alignment: .leading, spacing: 4) {
                Text(msg.message ?? "")
                if let ts = msg.timestamp {
                    Text(ts, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
        .navigationTitle(character.name ?? "Transcript")
    }
}
