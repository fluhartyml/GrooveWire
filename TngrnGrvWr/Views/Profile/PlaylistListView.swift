import SwiftUI
import SwiftData

struct PlaylistListView: View {
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bridge.createdAt, order: .reverse) private var bridges: [Bridge]
    @State private var playlists: [SpotifyPlaylist] = []
    @State private var selectedPlaylist: SpotifyPlaylist?
    @State private var trackCache: [String: [Track]] = [:]  // playlistID → tracks
    @State private var isLoadingPlaylists = false
    @State private var isLoadingTracks = false
    @State private var showBridgePicker = false

    // All tracks for the selected playlist, or all playlists combined
    private var displayedTracks: [Track] {
        if let selected = selectedPlaylist {
            return trackCache[selected.id] ?? []
        }
        // "All Songs" — flatten every cached playlist
        return playlists.flatMap { trackCache[$0.id] ?? [] }
    }

    private var trackSectionTitle: String {
        if let selected = selectedPlaylist {
            return "\(selected.name) (\(displayedTracks.count) tracks)"
        }
        let cached = trackCache.values.reduce(0) { $0 + $1.count }
        return "All Songs (\(cached) tracks)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top: Playlists ──
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Playlists")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    Spacer()
                    if isLoadingPlaylists {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing)
                            .padding(.top, 8)
                    }
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        // "All Songs" row
                        playlistButton(name: "All Songs", icon: "music.note", count: nil, isSelected: selectedPlaylist == nil) {
                            selectedPlaylist = nil
                        }

                        Divider().padding(.leading, 44)

                        ForEach(playlists) { playlist in
                            playlistButton(
                                name: playlist.name,
                                icon: playlist.isPublic ? "globe" : "lock.fill",
                                count: playlist.trackCount,
                                isSelected: selectedPlaylist?.id == playlist.id
                            ) {
                                selectedPlaylist = playlist
                                Task { await loadTracksIfNeeded(for: playlist) }
                            }
                            if playlist.id != playlists.last?.id {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(.ultraThinMaterial)

            Divider()

            // ── Bottom: Tracks ──
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(trackSectionTitle)
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    Spacer()
                    if !displayedTracks.isEmpty {
                        Button {
                            showBridgePicker = true
                        } label: {
                            Label("Load into Bridge", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.caption)
                        }
                        .padding(.trailing)
                        .padding(.top, 8)
                    }
                    if isLoadingTracks {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing)
                            .padding(.top, 8)
                    }
                }

                if displayedTracks.isEmpty && !isLoadingTracks {
                    VStack {
                        Spacer()
                        Text("Select a playlist above")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                        Spacer()
                    }
                } else {
                    List(displayedTracks) { track in
                        TrackRow(track: track)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .navigationTitle("My Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await loadPlaylists() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoadingPlaylists)
            }
        }
        .task {
            if playlists.isEmpty {
                await loadPlaylists()
            }
        }
        .sheet(isPresented: $showBridgePicker) {
            BridgePickerSheet(tracks: displayedTracks, bridges: bridges) { bridge in
                for track in displayedTracks {
                    bridge.tracks.append(track)
                }
                try? modelContext.save()
            }
        }
    }

    // MARK: - Playlist Row Button

    @ViewBuilder
    private func playlistButton(name: String, icon: String, count: Int?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? .orange : .secondary)

                Text(name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()

                if let count {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isSelected ? Color.orange.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data Loading

    private func loadPlaylists() async {
        isLoadingPlaylists = true
        defer { isLoadingPlaylists = false }
        do {
            playlists = try await spotifyService.fetchPlaylists()
        } catch {
            print("[Library] Playlist fetch failed: \(error.localizedDescription)")
        }
    }

    private func loadTracksIfNeeded(for playlist: SpotifyPlaylist) async {
        guard trackCache[playlist.id] == nil else { return }
        isLoadingTracks = true
        defer { isLoadingTracks = false }
        do {
            let tracks = try await spotifyService.fetchPlaylistTracks(playlistID: playlist.id)
            trackCache[playlist.id] = tracks
        } catch {
            print("[Library] Track fetch failed for \(playlist.name): \(error.localizedDescription)")
        }
    }
}
