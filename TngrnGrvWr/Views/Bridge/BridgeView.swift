import SwiftUI
import SwiftData

struct BridgeView: View {
    let bridge: Bridge

    @Environment(SpotifyService.self) private var spotifyService
    @Environment(PlaybackManager.self) private var playbackManager
    @Environment(\.modelContext) private var modelContext
    @State private var showSearch = false
    @State private var showShare = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var isSavingPlaylist = false
    @State private var savePlaylistMessage: String?
    @State private var showDeleteConfirm = false
    @State private var showMembers = false
    @State private var showAddPlaylist = false
    @State private var selectedTrackID: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Text(bridge.name)
                    .font(.title2.bold())
                    .listRowBackground(Color.clear)
            }
            nowPlayingSection
            queueSection
        }
        .background {
            // Hidden Escape key handler to deselect
            Button("") {
                selectedTrackID = nil
            }
            .keyboardShortcut(.escape, modifiers: [])
            .hidden()
        }
        .navigationTitle(bridge.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button { showSearch = true } label: {
                        Image(systemName: "plus")
                    }
                    Menu {
                        Button {
                            renameText = bridge.name
                            showRename = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button { showShare = true } label: {
                            Label("Invite", systemImage: "paperplane")
                        }

                        Divider()

                        Button {
                            if bridge.isActive { bridge.stopBridge() }
                            else { bridge.startBridge() }
                        } label: {
                            Label(
                                bridge.isActive ? "Stop Bridge" : "Start Bridge",
                                systemImage: bridge.isActive ? "stop.circle" : "play.circle"
                            )
                        }

                        if !bridge.trackList.isEmpty {
                            Button {
                                Task { await saveBridgeAsPlaylist() }
                            } label: {
                                Label("Save as Playlist", systemImage: "square.and.arrow.down.on.square")
                            }
                        }

                        Button {
                            showAddPlaylist = true
                        } label: {
                            Label("Add Playlist", systemImage: "text.badge.plus")
                        }

                        Toggle("Private Bridge", isOn: Binding(
                            get: { !bridge.isPublic },
                            set: { bridge.isPublic = !$0 }
                        ))

                        Divider()

                        Button {
                            showMembers = true
                        } label: {
                            Label("Members (\(bridge.participantCount))", systemImage: "person.2")
                        }

                        Divider()


                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Bridge", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            SearchView(bridge: bridge)
        }
        .sheet(isPresented: $showShare) {
            BridgeShareSheet(bridge: bridge)
        }
        .sheet(isPresented: $showMembers) {
            MembersSheet(bridge: bridge)
        }
        .sheet(isPresented: $showAddPlaylist) {
            AddPlaylistToBridgeSheet(bridge: bridge)
        }
        .alert("Rename Bridge", isPresented: $showRename) {
            TextField("Bridge name", text: $renameText)
            Button("Save") {
                let name = renameText.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { bridge.name = name }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Save as Playlist", isPresented: Binding(
            get: { savePlaylistMessage != nil },
            set: { if !$0 { savePlaylistMessage = nil } }
        )) {
            Button("OK") { savePlaylistMessage = nil }
        } message: {
            Text(savePlaylistMessage ?? "")
        }
        .alert("Delete Bridge?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(bridge)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove \"\(bridge.name)\" and all its tracks.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var nowPlayingSection: some View {
        Section("Now Playing") {
            if let track = playbackManager.currentTrack {
                NowPlayingRow(track: track)
                playbackControls
            } else {
                Text("Nothing playing")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var upcomingTracks: [Track] {
        if playbackManager.queue.isEmpty {
            return bridge.trackList
        }
        let afterCurrent = Array(playbackManager.queue.dropFirst(playbackManager.currentIndex + 1))
        let beforeCurrent = Array(playbackManager.queue.prefix(playbackManager.currentIndex))
        return afterCurrent + beforeCurrent
    }

    @ViewBuilder
    private var queueSection: some View {
        let upcoming = upcomingTracks
        Section(playbackManager.queue.isEmpty ? "Tracks (\(upcoming.count))" : "Up Next (\(upcoming.count))") {
            if upcoming.isEmpty {
                Text("No tracks — tap + to add some")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(upcoming) { track in
                    TrackRow(
                        track: track,
                        currentUserID: bridge.hostID, // TODO: replace with actual current user ID
                        onVoteUp: { track.vote(userID: bridge.hostID, isUpvote: true) },
                        onVoteDown: { track.vote(userID: bridge.hostID, isUpvote: false) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        playbackManager.play(track: track, from: bridge.trackList)
                        selectedTrackID = nil
                    }
                    .onTapGesture(count: 1) {
                        selectedTrackID = selectedTrackID == track.id ? nil : track.id
                    }
                    .listRowBackground(
                        selectedTrackID == track.id ? Color.orange.opacity(0.15) : nil
                    )
                    .swipeActions(edge: .trailing) {
                        Button {
                            track.vote(userID: bridge.hostID, isUpvote: false)
                        } label: {
                            Label("Thumbs Down", systemImage: "hand.thumbsdown")
                        }
                        .tint(.red)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            track.vote(userID: bridge.hostID, isUpvote: true)
                        } label: {
                            Label("Thumbs Up", systemImage: "hand.thumbsup")
                        }
                        .tint(.green)
                    }
                    .contextMenu {
                        Button {
                            track.vote(userID: bridge.hostID, isUpvote: true)
                        } label: {
                            Label("Thumbs Up", systemImage: "hand.thumbsup")
                        }

                        Button {
                            track.vote(userID: bridge.hostID, isUpvote: false)
                        } label: {
                            Label("Thumbs Down", systemImage: "hand.thumbsdown")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Playback

    @ViewBuilder
    private var playbackControls: some View {
        HStack(spacing: 32) {
            Spacer()

            Button { playbackManager.skipBackward() } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .disabled(!playbackManager.canSkipBackward)

            Button { playbackManager.togglePlayback() } label: {
                Image(systemName: playbackManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
            }

            Button { playbackManager.skipForward() } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .disabled(!playbackManager.canSkipForward)

            Spacer()
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }

    // MARK: - Save as Playlist

    private func saveBridgeAsPlaylist() async {
        guard !bridge.trackList.isEmpty else { return }
        isSavingPlaylist = true
        defer { isSavingPlaylist = false }

        let playlistName = bridge.name
        let trackIDs = bridge.trackList.compactMap { $0.spotifyID }

        var spotifyPlaylistID: String?

        // Create on Spotify if connected and we have Spotify track IDs
        if spotifyService.isConnected, !trackIDs.isEmpty {
            do {
                let desc = "Saved from GrooveWire bridge"
                spotifyPlaylistID = try await spotifyService.createPlaylist(
                    name: playlistName,
                    description: desc,
                    trackIDs: trackIDs
                )
                print("[Bridge] Created Spotify playlist '\(playlistName)' with \(trackIDs.count) tracks")
            } catch {
                print("[Bridge] Spotify playlist creation failed: \(error.localizedDescription)")
                // Continue — still save locally even if Spotify fails
            }
        }

        // Save locally in SwiftData
        let savedPlaylist = SavedPlaylist(
            name: playlistName,
            spotifyPlaylistID: spotifyPlaylistID,
            playlistDescription: "Saved from bridge",
            isPublic: bridge.isPublic
        )
        modelContext.insert(savedPlaylist)

        for track in bridge.trackList {
            let localTrack = Track(
                title: track.title,
                artist: track.artist,
                albumTitle: track.albumTitle,
                artworkURL: track.artworkURL,
                spotifyID: track.spotifyID,
                durationSeconds: track.durationSeconds,
                addedBy: track.addedBy
            )
            localTrack.savedPlaylist = savedPlaylist
            modelContext.insert(localTrack)
            savedPlaylist.trackList.append(localTrack)
        }

        do {
            try modelContext.save()
            let spotifyNote = spotifyPlaylistID != nil ? " and Spotify" : ""
            savePlaylistMessage = "Saved '\(playlistName)' with \(bridge.trackList.count) tracks to your library\(spotifyNote)!"
            print("[Bridge] Saved playlist '\(playlistName)' locally with \(bridge.trackList.count) tracks")
        } catch {
            savePlaylistMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

}

// MARK: - Now Playing Row

private struct NowPlayingRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(width: 60, height: 60)
                .overlay {
                    if let url = track.artworkURL, let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let album = track.albumTitle {
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BridgeView(bridge: Bridge(name: "Chill Vibes", hostID: UUID()))
    }
}
