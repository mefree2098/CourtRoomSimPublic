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
                            Text(formatSpeaker(ev.speaker ?? "—"))
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
    
    private func formatSpeaker(_ speaker: String) -> String {
        // If the speaker is the judge, return as is
        if speaker.lowercased() == "judge" {
            return "Judge"
        }
        
        // If it's a witness or other character, return their name
        if !speaker.contains("(AI)") && !speaker.contains("Prosecution") && !speaker.contains("Defense") {
            return speaker
        }
        
        // For AI counsel, format as "Role Character Name (AI)"
        if let role = speaker.components(separatedBy: " ").first,
           let name = speaker.components(separatedBy: " ").last {
            return "\(role) \(name) (AI)"
        }
        
        return speaker
    }
}
