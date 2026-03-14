import SwiftUI
import SwiftData

struct PlaylistDetailView: View {
    let playlist: SpotifyPlaylist

    @Environment(SpotifyService.self) private var spotifyService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bridge.createdAt, order: .reverse) private var bridges: [Bridge]
    @State private var tracks: [Track] = []
    @State private var isLoading = false
    @State private var showBridgePicker = false

    private var shareText: String {
        let trackList = tracks.prefix(10).enumerated().map { "\($0.offset + 1). \($0.element.artist) — \($0.element.title)" }.joined(separator: "\n")
        let more = tracks.count > 10 ? "\n+ \(tracks.count - 10) more" : ""
        return "\(playlist.name)\n\(trackList)\(more)"
    }

    var body: some View {
        List {
            // Header
            Section {
                HStack(spacing: 14) {
                    if let url = playlist.imageURL, let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 10).fill(.quaternary)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.name)
                            .font(.title3.bold())
                        if let desc = playlist.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        HStack(spacing: 8) {
                            Label("\(playlist.trackCount)", systemImage: "music.note")
                            Image(systemName: playlist.isPublic ? "globe" : "lock.fill")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)
            }

            // Actions
            Section {
                Button {
                    showBridgePicker = true
                } label: {
                    Label("Load into Bridge", systemImage: "antenna.radiowaves.left.and.right")
                }
                .disabled(tracks.isEmpty)

                ShareLink(
                    item: shareText,
                    preview: SharePreview(playlist.name, image: Image(systemName: "music.note.list"))
                ) {
                    Label("Share Playlist", systemImage: "square.and.arrow.up")
                }
                .disabled(tracks.isEmpty)
            }

            // Track list
            Section("Tracks") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading tracks...")
                        Spacer()
                    }
                } else if tracks.isEmpty {
                    Text("No tracks found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tracks) { track in
                        TrackRow(track: track)
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if tracks.isEmpty {
                await loadTracks()
            }
        }
        .sheet(isPresented: $showBridgePicker) {
            BridgePickerSheet(tracks: tracks, bridges: bridges) { bridge in
                loadIntoBridge(bridge)
            }
        }
    }

    private func loadTracks() async {
        isLoading = true
        defer { isLoading = false }
        do {
            tracks = try await spotifyService.fetchPlaylistTracks(playlistID: playlist.id)
        } catch {
            print("[PlaylistDetail] Fetch tracks failed: \(error.localizedDescription)")
        }
    }

    private func loadIntoBridge(_ bridge: Bridge) {
        for track in tracks {
            bridge.tracks.append(track)
        }
        try? modelContext.save()
    }
}

// MARK: - Bridge Picker

struct BridgePickerSheet: View {
    let tracks: [Track]
    let bridges: [Bridge]
    let onSelect: (Bridge) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if bridges.isEmpty {
                    Text("No bridges yet — create one first.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bridges) { bridge in
                        Button {
                            onSelect(bridge)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(bridge.name)
                                        .font(.headline)
                                    Text("\(bridge.tracks.count) tracks")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("+\(tracks.count)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Load into Bridge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
