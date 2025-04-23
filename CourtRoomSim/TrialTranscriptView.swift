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
    
    // Search state
    @State private var searchText = ""
    @State private var searchResults: [UUID] = []
    @State private var currentSearchIndex = 0
    @State private var isSearching = false
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            if isSearching {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search transcript...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: searchText) { _ in
                            performSearch()
                        }
                    
                    if !searchResults.isEmpty {
                        Text("\(currentSearchIndex + 1) of \(searchResults.count)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Button {
                            currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
                            scrollToSearchResult()
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(searchResults.isEmpty)
                        
                        Button {
                            currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
                            scrollToSearchResult()
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(searchResults.isEmpty)
                    }
                    
                    Button {
                        isSearching = false
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
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
                                    .background(
                                        searchResults.contains(ev.id ?? UUID()) ?
                                        Color.yellow.opacity(0.3) :
                                        Color.gray.opacity(0.1)
                                    )
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
                .onAppear {
                    scrollProxy = proxy
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isSearching.toggle()
                    if !isSearching {
                        searchText = ""
                        searchResults = []
                    }
                } label: {
                    Image(systemName: isSearching ? "magnifyingglass.circle.fill" : "magnifyingglass")
                }
                .help("Search transcript")
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
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        searchResults = events
            .filter { event in
                let message = event.message?.lowercased() ?? ""
                let speaker = event.speaker?.lowercased() ?? ""
                return message.contains(searchText.lowercased()) ||
                       speaker.contains(searchText.lowercased())
            }
            .compactMap { $0.id }
        
        currentSearchIndex = 0
        if !searchResults.isEmpty {
            scrollToSearchResult()
        }
    }
    
    private func scrollToSearchResult() {
        guard !searchResults.isEmpty else { return }
        withAnimation {
            scrollProxy?.scrollTo(searchResults[currentSearchIndex], anchor: .center)
        }
    }
}
