//
//  TrialTranscriptView.swift
//  CourtRoomSim
//
//  Displays the scrolling transcript of TrialEvent records.
//  Works with the FetchRequest passed in from TrialFlowView.
//

import SwiftUI
import CoreData

struct TrialTranscriptView: View {

    // A plain FetchedResults list of TrialEvent objects
    var events: FetchedResults<TrialEvent>

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(events) { ev in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ev.speaker ?? "—")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(ev.message ?? "")
                                .padding(6)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .id(ev.id)        // for auto‑scroll
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: events.count) { _ in
                proxy.scrollTo(events.last?.id, anchor: .bottom)
            }
        }
    }
}
