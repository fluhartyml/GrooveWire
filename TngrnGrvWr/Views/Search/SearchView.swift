import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(TrackMatchingService.self) private var matchingService
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

                // Service status bar
                HStack(spacing: 16) {
                    if spotifyService.isConnected {
                        Label("Spotify", systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    if appleMusicService.isConnected {
                        Label("Apple Music", systemImage: "apple.logo")
                            .font(.caption2)
                            .foregroundStyle(.pink)
                    }
                    if !spotifyService.isConnected && !appleMusicService.isConnected {
                        Text("No services connected")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if spotifyService.isConnected && appleMusicService.isConnected {
                        Text("Searching both services")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

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
        print("[SearchView] performSearch() — query: '\(query)'")
        guard !query.isEmpty else { return }
        isSearching = true
        hasSearched = true
        error = nil

        let bothConnected = spotifyService.isConnected && appleMusicService.isConnected
        print("[SearchView] Spotify: \(spotifyService.isConnected), Apple Music: \(appleMusicService.isConnected)")

        Task {
            do {
                if bothConnected {
                    // Both connected — search both and merge/deduplicate
                    print("[SearchView] Dual-service search...")
                    results = await matchingService.searchBothServices(query: query)
                    print("[SearchView] Got \(results.count) merged results")
                } else if spotifyService.isConnected {
                    print("[SearchView] Spotify-only search...")
                    results = try await spotifyService.search(query: query)
                    print("[SearchView] Got \(results.count) results from Spotify")
                } else if appleMusicService.isConnected {
                    print("[SearchView] Apple Music-only search...")
                    results = try await appleMusicService.search(query: query)
                    print("[SearchView] Got \(results.count) results from Apple Music")
                } else {
                    error = "Connect a streaming service in Profile to search."
                }
            } catch {
                print("[SearchView] ERROR: \(error)")
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
        bridge.trackList.append(newTrack)
        modelContext.insert(newTrack)

        // Brief haptic feedback
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
