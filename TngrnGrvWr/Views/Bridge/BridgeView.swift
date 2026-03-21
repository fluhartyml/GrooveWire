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
    @State private var djMode = false
    @State private var queueVersion = 0
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
                            bridge.startBridge()
                            if let first = bridge.trackList.first {
                                playbackManager.play(track: first, from: bridge.trackList)
                            }
                        } label: {
                            Label("Start GrooveWire Bridge", systemImage: "play.circle")
                        }

                        Button {
                            bridge.stopBridge()
                            playbackManager.pause()
                        } label: {
                            Label("Stop GrooveWire Bridge", systemImage: "stop.circle")
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

                        Toggle("Private GrooveWire Bridge", isOn: Binding(
                            get: { !bridge.isPublic },
                            set: { bridge.isPublic = !$0 }
                        ))

                        Toggle("DJ Mode", isOn: $djMode)

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
                            Label("Delete GrooveWire Bridge", systemImage: "trash")
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
        .alert("Rename GrooveWire Bridge", isPresented: $showRename) {
            TextField("GrooveWire Bridge name", text: $renameText)
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
        .alert("Delete GrooveWire Bridge?", isPresented: $showDeleteConfirm) {
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

    private var queueBelongsToBridge: Bool {
        guard !playbackManager.queue.isEmpty else { return false }
        // Check if the queue's tracks are from this bridge
        let queueIDs = Set(playbackManager.queue.map { $0.id })
        let bridgeIDs = Set(bridge.trackList.map { $0.id })
        return !queueIDs.isDisjoint(with: bridgeIDs)
    }

    private var upcomingTracks: [Track] {
        if queueBelongsToBridge {
            let afterCurrent = Array(playbackManager.queue.dropFirst(playbackManager.currentIndex + 1))
            let beforeCurrent = Array(playbackManager.queue.prefix(playbackManager.currentIndex))
            return afterCurrent + beforeCurrent
        }
        return bridge.trackList
    }

    @ViewBuilder
    private var queueSection: some View {
        let trackCount = bridge.trackList.count
        Section(queueBelongsToBridge ? "Up Next (\(trackCount))" : "Tracks (\(trackCount))") {
            if bridge.trackList.isEmpty {
                Text("No tracks — tap + to add some")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(bridge.trackList) { track in
                    TrackRow(
                        track: track,
                        currentUserID: bridge.hostID,
                        onVoteUp: {
                            track.vote(userID: bridge.hostID, isUpvote: true)
                            if djMode {
                                moveTrackToFront(track)
                            } else if track.voteScore > 0 {
                                moveTrack(track, direction: .up)
                            }
                        },
                        onVoteDown: {
                            track.vote(userID: bridge.hostID, isUpvote: false)
                            if djMode {
                                moveTrackToBack(track)
                            } else if track.voteScore < 0 {
                                moveTrack(track, direction: .down)
                            }
                        }
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
                    .contextMenu {
                        Button {
                            track.vote(userID: bridge.hostID, isUpvote: true)
                            if djMode {
                                moveTrackToFront(track)
                            } else if track.voteScore > 0 {
                                moveTrack(track, direction: .up)
                            }
                        } label: {
                            Label(djMode ? "Play Next (DJ)" : "Thumbs Up", systemImage: "hand.thumbsup")
                        }

                        Button {
                            track.vote(userID: bridge.hostID, isUpvote: false)
                            if djMode {
                                moveTrackToBack(track)
                            } else if track.voteScore < 0 {
                                moveTrack(track, direction: .down)
                            }
                        } label: {
                            Label(djMode ? "Play Last (DJ)" : "Thumbs Down", systemImage: "hand.thumbsdown")
                        }

                        Divider()

                        if bridge.trackList.first?.id != track.id {
                            Button {
                                moveTrack(track, direction: .up)
                            } label: {
                                Label("Move Up", systemImage: "arrow.up")
                            }
                        }

                        if bridge.trackList.last?.id != track.id {
                            Button {
                                moveTrack(track, direction: .down)
                            } label: {
                                Label("Move Down", systemImage: "arrow.down")
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            removeTrack(track)
                        } label: {
                            Label("Remove from Queue", systemImage: "trash")
                        }
                    }
                }
                .onMove { from, to in
                    bridge.trackList.move(fromOffsets: from, toOffset: to)
                    // Sync playback queue if it belongs to this bridge
                    if queueBelongsToBridge {
                        playbackManager.queue = bridge.trackList
                        if let current = playbackManager.currentTrack {
                            playbackManager.currentIndex = bridge.trackList.firstIndex(where: { $0.id == current.id }) ?? 0
                        }
                    }
                    try? modelContext.save()
                    queueVersion += 1
                }
            }
        }
        .id(queueVersion)
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

    // MARK: - Reorder

    enum MoveDirection { case up, down }

    private func moveTrack(_ track: Track, direction: MoveDirection) {
        var tracks = bridge.trackList
        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        let newIndex = direction == .up ? index - 1 : index + 1
        guard newIndex >= 0 && newIndex < tracks.count else { return }

        tracks.swapAt(index, newIndex)
        bridge.trackList = tracks

        if queueBelongsToBridge {
            playbackManager.queue = bridge.trackList
            if let current = playbackManager.currentTrack {
                playbackManager.currentIndex = bridge.trackList.firstIndex(where: { $0.id == current.id }) ?? 0
            }
        }
        try? modelContext.save()
        queueVersion += 1
    }

    // MARK: - DJ Queue Control

    private func moveTrackToFront(_ track: Track) {
        guard let index = bridge.trackList.firstIndex(where: { $0.id == track.id }),
              index > 0 else { return }
        let removed = bridge.trackList.remove(at: index)
        bridge.trackList.insert(removed, at: 0)
        syncQueueToBridge()
    }

    private func moveTrackToBack(_ track: Track) {
        guard let index = bridge.trackList.firstIndex(where: { $0.id == track.id }),
              index < bridge.trackList.count - 1 else { return }
        let removed = bridge.trackList.remove(at: index)
        bridge.trackList.append(removed)
        syncQueueToBridge()
    }

    private func syncQueueToBridge() {
        if queueBelongsToBridge {
            playbackManager.queue = bridge.trackList
            if let current = playbackManager.currentTrack {
                playbackManager.currentIndex = bridge.trackList.firstIndex(where: { $0.id == current.id }) ?? 0
            }
        }
        try? modelContext.save()
        queueVersion += 1
    }

    // MARK: - Remove Track

    private func removeTrack(_ track: Track) {
        bridge.trackList.removeAll { $0.id == track.id }
        playbackManager.queue.removeAll { $0.id == track.id }
        modelContext.delete(track)
        try? modelContext.save()
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
            playlistDescription: "Saved from GrooveWire Bridge",
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
