import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let bridge: Bridge

    @State private var query = ""
    @State private var results: [Track] = []
    @State private var isSearching = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                if results.isEmpty && !isSearching && !query.isEmpty {
                    ContentUnavailableView.search(text: query)
                }

                ForEach(results) { track in
                    Button {
                        addTrack(track)
                    } label: {
                        HStack {
                            TrackRow(track: track)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .tint(.primary)
                }
            }
            .searchable(text: $query, prompt: "Search for songs...")
            .onSubmit(of: .search) { performSearch() }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty { results = [] }
            }
            .navigationTitle("Add Tracks")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if isSearching {
                    ProgressView("Searching...")
                }
            }
        }
    }

    private func performSearch() {
        guard !query.isEmpty else { return }
        isSearching = true
        error = nil

        Task {
            do {
                if spotifyService.isConnected {
                    results = try await spotifyService.search(query: query)
                } else if appleMusicService.isConnected {
                    results = try await appleMusicService.search(query: query)
                } else {
                    error = "Connect a streaming service in Profile to search."
                }
            } catch {
                self.error = error.localizedDescription
            }
            isSearching = false
        }
    }

    private func addTrack(_ track: Track) {
        let newTrack = Track(
            title: track.title,
            artist: track.artist,
            albumTitle: track.albumTitle,
            artworkURL: track.artworkURL,
            appleMusicID: track.appleMusicID,
            spotifyID: track.spotifyID,
            durationSeconds: track.durationSeconds,
            addedBy: track.addedBy
        )
        bridge.tracks.append(newTrack)
        modelContext.insert(newTrack)

        // Brief haptic feedback
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
