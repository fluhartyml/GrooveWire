import SwiftUI
import SwiftData

struct LibraryListView: View {
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(PlaybackManager.self) private var playbackManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Query(sort: \SavedPlaylist.createdAt, order: .reverse) private var savedPlaylists: [SavedPlaylist]
    @State private var selectedPlaylist: SavedPlaylist?
    @State private var showAddPlaylist = false
    @State private var transferTarget: SavedPlaylist?
    @State private var transferPlaylists: [SavedPlaylist]?
    @State private var selectedForTransfer: Set<PersistentIdentifier> = []
    @State private var isSelectMode = false
    @State private var exportPlaylist: SavedPlaylist?
    @State private var searchTargetPlaylist: SavedPlaylist?
    @State private var sharePlaylist: SavedPlaylist?
    @State private var isSyncing = false
    @State private var syncMessage: String?

    private var displayedTracks: [Track] {
        if let selected = selectedPlaylist {
            return selected.trackList
        }
        return savedPlaylists.flatMap { $0.trackList }
    }

    private var trackSectionTitle: String {
        if let selected = selectedPlaylist {
            return "\(selected.name) (\(selected.trackCount) tracks)"
        }
        let total = savedPlaylists.reduce(0) { $0 + $1.trackCount }
        return "All Songs (\(total) tracks)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top: Playlists (iTunes-inspired)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Playlists")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    Spacer()
                }

                List {
                    playlistButton(name: "All Songs", icon: "music.note", count: nil, isSelected: selectedPlaylist == nil) {
                        selectedPlaylist = nil
                    }

                    ForEach(savedPlaylists) { playlist in
                        playlistRow(playlist)
                        .contextMenu {
                            Button {
                                searchTargetPlaylist = playlist
                            } label: {
                                Label("Add Tracks", systemImage: "plus.circle")
                            }

                            Button {
                                playlist.isPublic.toggle()
                                try? modelContext.save()
                            } label: {
                                Label(playlist.isPublic ? "Make Private" : "Make Public",
                                      systemImage: playlist.isPublic ? "lock.fill" : "globe")
                            }

                            if playlist.trackList.contains(where: { $0.spotifyID != nil }) && spotifyService.isConnected {
                                Button {
                                    let tracks = playlist.trackList.sorted { ($0.sortOrder) < ($1.sortOrder) }
                                    if let first = tracks.first {
                                        playbackManager.play(track: first, from: tracks)
                                    }
                                } label: {
                                    Label("Spotify Queue", systemImage: "hifispeaker.fill")
                                }
                            }

                            Button {
                                sharePlaylist = playlist
                            } label: {
                                Label("Share Playlist", systemImage: "square.and.arrow.up")
                            }

                            Button {
                                transferTarget = playlist
                            } label: {
                                Label("Transfer to Streaming Service", systemImage: "arrow.triangle.swap")
                            }

                            Button {
                                exportPlaylist = playlist
                            } label: {
                                Label("Export Playlist", systemImage: "square.and.arrow.up")
                            }

                            Divider()

                            Button(role: .destructive) {
                                deletePlaylist(playlist)
                            } label: {
                                Label("Remove from Library", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .frame(maxHeight: .infinity)
            .background(.ultraThinMaterial)

            Divider()

            // Bottom: Tracks
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(trackSectionTitle)
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    Spacer()
                }

                if displayedTracks.isEmpty {
                    VStack {
                        Spacer()
                        Text("Select a playlist above")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                        Spacer()
                    }
                } else {
                    List(displayedTracks) { track in
                        HStack {
                            TrackRow(track: track)
                            Spacer()
                            Button {
                                playbackManager.play(track: track, from: displayedTracks)
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.caption2)
                                    .foregroundStyle(themeColor)
                            }
                            .buttonStyle(.plain)
                        }
                        .contextMenu {
                            if let playlist = selectedPlaylist {
                                Button(role: .destructive) {
                                    removeTrack(track, from: playlist)
                                } label: {
                                    Label("Remove from Playlist", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .navigationTitle("My Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    if spotifyService.isConnected {
                        Button {
                            Task { await syncFromSpotify() }
                        } label: {
                            if isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                        }
                        .disabled(isSyncing)
                        .help("Sync from Spotify")
                    }

                    if isSelectMode {
                        Button {
                            let playlists = savedPlaylists.filter { selectedForTransfer.contains($0.persistentModelID) }
                            if !playlists.isEmpty {
                                transferPlaylists = playlists
                            }
                            isSelectMode = false
                            selectedForTransfer = []
                        } label: {
                            Text("Transfer (\(selectedForTransfer.count))")
                                .font(.caption)
                        }
                        .disabled(selectedForTransfer.isEmpty)

                        Button {
                            isSelectMode = false
                            selectedForTransfer = []
                        } label: {
                            Text("Cancel")
                                .font(.caption)
                        }
                    } else {
                        Button {
                            isSelectMode = true
                        } label: {
                            Image(systemName: "checklist")
                        }
                        .help("Select playlists to transfer")
                    }

                    Button {
                        showAddPlaylist = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .alert("Spotify Sync", isPresented: Binding(
            get: { syncMessage != nil },
            set: { if !$0 { syncMessage = nil } }
        )) {
            Button("OK") { syncMessage = nil }
        } message: {
            Text(syncMessage ?? "")
        }
        .sheet(isPresented: $showAddPlaylist) {
            ImportPlaylistSheet()
        }
        .sheet(item: $searchTargetPlaylist) { playlist in
            AddTracksToPlaylistSheet(playlist: playlist, spotifyService: spotifyService)
        }
        .sheet(item: $transferTarget) { playlist in
            PlaylistTransferSheet(playlist: playlist)
        }
        .sheet(isPresented: Binding(
            get: { transferPlaylists != nil },
            set: { if !$0 { transferPlaylists = nil } }
        )) {
            if let playlists = transferPlaylists {
                BatchTransferSheet(playlists: playlists)
            }
        }
        .sheet(item: $exportPlaylist) { playlist in
            M3UExportSheet(playlist: playlist)
        }
        .sheet(item: $sharePlaylist) { playlist in
            PlaylistShareSheet(playlist: playlist)
        }
    }

    // MARK: - Playlist Row

    @ViewBuilder
    private func playlistRow(_ playlist: SavedPlaylist) -> some View {
        if isSelectMode {
            selectModeRow(playlist)
        } else {
            playlistButton(
                name: playlist.name,
                icon: playlist.isPublic ? "globe" : "lock.fill",
                count: playlist.trackCount,
                isSelected: selectedPlaylist?.id == playlist.id
            ) {
                selectedPlaylist = playlist
            }
        }
    }

    @ViewBuilder
    private func selectModeRow(_ playlist: SavedPlaylist) -> some View {
        let isChecked = selectedForTransfer.contains(playlist.persistentModelID)
        Button {
            if isChecked {
                selectedForTransfer.remove(playlist.persistentModelID)
            } else {
                selectedForTransfer.insert(playlist.persistentModelID)
            }
        } label: {
            HStack {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? themeColor : .secondary)
                Text(playlist.name)
                    .font(.subheadline)
                Spacer()
                Text("\(playlist.trackCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func playlistButton(name: String, icon: String, count: Int?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? themeColor : .secondary)

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
            .background(isSelected ? themeColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func removeTrack(_ track: Track, from playlist: SavedPlaylist) {
        playlist.trackList.removeAll { $0.id == track.id }
        modelContext.delete(track)
        try? modelContext.save()
    }

    private func deletePlaylist(_ playlist: SavedPlaylist) {
        if let spotifyID = playlist.spotifyPlaylistID {
            Task {
                try? await spotifyService.unfollowPlaylist(playlistID: spotifyID)
            }
        }
        if selectedPlaylist?.id == playlist.id {
            selectedPlaylist = nil
        }
        modelContext.delete(playlist)
        try? modelContext.save()
    }

    private func syncFromSpotify() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let remotePlaylists = try await spotifyService.fetchPlaylists()
            let existingIDs = Set(savedPlaylists.compactMap { $0.spotifyPlaylistID })

            var added = 0
            var skipped = 0
            for remote in remotePlaylists {
                guard !existingIDs.contains(remote.id) else { continue }

                let tracks: [Track]
                do {
                    tracks = try await spotifyService.fetchPlaylistTracks(playlistID: remote.id)
                } catch SpotifyError.forbidden {
                    skipped += 1
                    continue
                }

                let saved = SavedPlaylist(
                    name: remote.name,
                    spotifyPlaylistID: remote.id,
                    playlistDescription: remote.description,
                    isPublic: false,
                    imageURL: remote.imageURL,
                    ownerName: remote.ownerName
                )
                modelContext.insert(saved)

                for track in tracks {
                    let localTrack = Track(
                        title: track.title,
                        artist: track.artist,
                        albumTitle: track.albumTitle,
                        artworkURL: track.artworkURL,
                        spotifyID: track.spotifyID,
                        durationSeconds: track.durationSeconds
                    )
                    localTrack.savedPlaylist = saved
                    modelContext.insert(localTrack)
                    saved.trackList.append(localTrack)
                }

                added += 1
            }

            try modelContext.save()

            var message = ""
            if added > 0 {
                message = "Added \(added) new playlist\(added == 1 ? "" : "s") from Spotify."
            } else {
                message = "All Spotify playlists are already in your library."
            }
            if skipped > 0 {
                message += " \(skipped) skipped (access denied)."
            }
            syncMessage = message
        } catch {
            syncMessage = "Sync failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    LibraryListView()
}
