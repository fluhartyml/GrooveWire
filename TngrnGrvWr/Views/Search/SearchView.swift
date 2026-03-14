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
    @State private var hasSearched = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    TextField("Search for songs...", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { performSearch() }

                    Button("Search") { performSearch() }
                        .disabled(query.isEmpty || isSearching)
                }
                .padding()

                // Results
                List {
                    if let error {
                        Section {
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }

                    if results.isEmpty && !isSearching && hasSearched {
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
                .overlay {
                    if isSearching {
                        ProgressView("Searching...")
                    }
                }
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
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func performSearch() {
        print("🔍 [SearchView] performSearch() CALLED — query: '\(query)'")
        guard !query.isEmpty else {
            print("🔍 [SearchView] query is empty, returning")
            return
        }
        isSearching = true
        hasSearched = true
        error = nil
        print("🔍 [SearchView] Spotify connected: \(spotifyService.isConnected), Apple Music connected: \(appleMusicService.isConnected)")

        Task {
            do {
                if spotifyService.isConnected {
                    print("🔍 [SearchView] Calling Spotify search...")
                    results = try await spotifyService.search(query: query)
                    print("🔍 [SearchView] Got \(results.count) results from Spotify")
                } else if appleMusicService.isConnected {
                    print("🔍 [SearchView] Calling Apple Music search...")
                    results = try await appleMusicService.search(query: query)
                    print("🔍 [SearchView] Got \(results.count) results from Apple Music")
                } else {
                    print("🔍 [SearchView] No service connected!")
                    error = "Connect a streaming service in Profile to search."
                }
            } catch {
                print("🔍 [SearchView] ERROR: \(error)")
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
