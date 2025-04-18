// NotebookView.swift
// CourtRoomSim

import SwiftUI
import CoreData

struct NotebookView: View {
    @ObservedObject var caseEntity: CaseEntity
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @FetchRequest private var entries: FetchedResults<NotebookEntry>
    @State private var draft = ""

    init(caseEntity: CaseEntity) {
        self.caseEntity = caseEntity
        let req = NSFetchRequest<NotebookEntry>(entityName: "NotebookEntry")
        req.predicate = NSPredicate(format: "caseEntity == %@", caseEntity)
        req.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        _entries = FetchRequest(fetchRequest: req)
    }

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(entries, id: \.id) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.content ?? "")
                            if let ts = note.timestamp {
                                Text(ts, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: delete)
                }

                Divider().padding(.vertical, 8)

                VStack {
                    TextEditor(text: $draft)
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3))
                        )
                    HStack {
                        Spacer()
                        Button("Save Note") {
                            let n = NotebookEntry(context: ctx)
                            n.id = UUID()
                            n.content = draft
                            n.timestamp = Date()
                            n.caseEntity = caseEntity
                            try? ctx.save()
                            draft = ""
                        }
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding()
            }
            .navigationTitle("Notebook")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        offsets.map { entries[$0] }.forEach(ctx.delete)
        try? ctx.save()
    }
}
