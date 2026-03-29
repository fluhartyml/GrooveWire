import SwiftUI
import SwiftData

struct AddTracksToPlaylistSheet: View {
    let playlist: SavedPlaylist
    let spotifyService: SpotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @State private var searchQuery = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching = false
    @State private var addedCount = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    TextField("Search songs...", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task { await search() }
                        }
                    Button {
                        Task { await search() }
                    } label: {
                        if isSearching {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                    .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                }
                .padding()

                if addedCount > 0 {
                    Text("\(addedCount) track\(addedCount == 1 ? "" : "s") added to \(playlist.name)")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal)
                }

                if searchResults.isEmpty {
                    Spacer()
                    Text("Search for songs to add to \"\(playlist.name)\"")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List(searchResults) { track in
                        HStack(spacing: 10) {
                            if let urlString = track.artworkURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if track.spotifyID != nil {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                            if track.appleMusicID != nil {
                                Image(systemName: "apple.logo")
                                    .font(.caption2)
                                    .foregroundStyle(.pink)
                            }

                            Button {
                                addTrack(track)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(themeColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Tracks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 350)
    }

    private func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true

        var results: [Track] = []

        if spotifyService.isConnected {
            do {
                let spotifyResults = try await spotifyService.search(query: query)
                results.append(contentsOf: spotifyResults)
            } catch {
                print("[AddTracks] Spotify search failed: \(error.localizedDescription)")
            }
        }

        if appleMusicService.isConnected {
            do {
                let appleResults = try await appleMusicService.search(query: query)
                let existingKeys = Set(results.map { "\($0.title.lowercased())|\($0.artist.lowercased())" })
                for track in appleResults {
                    let key = "\(track.title.lowercased())|\(track.artist.lowercased())"
                    if !existingKeys.contains(key) {
                        results.append(track)
                    }
                }
            } catch {
                print("[AddTracks] Apple Music search failed: \(error.localizedDescription)")
            }
        }

        searchResults = results
        isSearching = false
    }

    private func addTrack(_ track: Track) {
        let newTrack = Track(
            title: track.title,
            artist: track.artist,
            albumTitle: track.albumTitle,
            artworkURL: track.artworkURL,
            appleMusicID: track.appleMusicID,
            spotifyID: track.spotifyID,
            durationSeconds: track.durationSeconds
        )
        newTrack.savedPlaylist = playlist
        modelContext.insert(newTrack)
        playlist.trackList.append(newTrack)
        try? modelContext.save()
        addedCount += 1
    }
}
