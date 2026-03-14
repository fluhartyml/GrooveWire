import SwiftUI
import SwiftData

struct BridgeView: View {
    let bridge: Bridge

    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @State private var showSearch = false
    @State private var showShare = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var isPlaying = false
    @State private var currentIndex = 0

    var body: some View {
        List {
            nowPlayingSection
            queueSection
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

                        Toggle("Private Bridge", isOn: Binding(
                            get: { !bridge.isPublic },
                            set: { bridge.isPublic = !$0 }
                        ))

                        if bridge.guestCount > 0 {
                            Divider()
                            Menu("Members (\(bridge.participantCount))") {
                                ForEach(bridge.membersByRole, id: \.role) { group in
                                    Section(group.role.displayName) {
                                        ForEach(group.userIDs, id: \.self) { userID in
                                            if group.role == .host {
                                                Label(userID.prefix(8) + "...", systemImage: group.role.iconName)
                                            } else {
                                                Menu("\(userID.prefix(8))...") {
                                                    // Role changes
                                                    if group.role != .cohost {
                                                        Button {
                                                            if let uuid = UUID(uuidString: userID) { bridge.promoteToCohost(uuid) }
                                                        } label: { Label("Make Co-Host", systemImage: "crown") }
                                                    }
                                                    if group.role != .bouncer {
                                                        Button {
                                                            if let uuid = UUID(uuidString: userID) { bridge.promoteToBouncer(uuid) }
                                                        } label: { Label("Make Bouncer", systemImage: "shield.checkered") }
                                                    }
                                                    if group.role != .participant {
                                                        Button {
                                                            if let uuid = UUID(uuidString: userID) { bridge.demoteToParticipant(uuid) }
                                                        } label: { Label("Make Participant", systemImage: "person.fill") }
                                                    }
                                                    if group.role != .listener {
                                                        Button {
                                                            if let uuid = UUID(uuidString: userID) { bridge.demoteToListener(uuid) }
                                                        } label: { Label("Make Listener", systemImage: "headphones") }
                                                    }
                                                    Divider()
                                                    Button(role: .destructive) {
                                                        if let uuid = UUID(uuidString: userID) { bridge.kick(uuid) }
                                                    } label: { Label("Kick", systemImage: "hand.raised") }
                                                    Button(role: .destructive) {
                                                        if let uuid = UUID(uuidString: userID) { bridge.ban(uuid) }
                                                    } label: { Label("Ban", systemImage: "xmark.shield") }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
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
        .alert("Rename Bridge", isPresented: $showRename) {
            TextField("Bridge name", text: $renameText)
            Button("Save") {
                let name = renameText.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { bridge.name = name }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Sections

    private var currentTrack: Track? {
        guard !bridge.tracks.isEmpty, currentIndex < bridge.tracks.count else { return nil }
        return bridge.tracks[currentIndex]
    }

    @ViewBuilder
    private var nowPlayingSection: some View {
        Section("Now Playing") {
            if let track = currentTrack {
                NowPlayingRow(track: track)
                playbackControls(for: track)
            } else {
                Text("Nothing playing")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var queueSection: some View {
        let upcoming = bridge.tracks.count > currentIndex + 1
            ? Array(bridge.tracks[(currentIndex + 1)...])
            : []
        Section("Up Next (\(upcoming.count))") {
            if upcoming.isEmpty {
                Text("Queue is empty — tap + to add tracks")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(upcoming) { track in
                    TrackRow(track: track)
                }
            }
        }
    }

    // MARK: - Playback

    @ViewBuilder
    private func playbackControls(for track: Track) -> some View {
        HStack(spacing: 32) {
            Spacer()

            Button { skipBackward() } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            .disabled(currentIndex == 0)

            Button { togglePlayback(track: track) } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
            }

            Button { skipForward() } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
            .disabled(currentIndex >= bridge.tracks.count - 1)

            Spacer()
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }

    private func skipForward() {
        guard currentIndex < bridge.tracks.count - 1 else { return }
        currentIndex += 1
        if isPlaying, let track = currentTrack {
            Task {
                try? await playTrack(track)
            }
        }
    }

    private func skipBackward() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        if isPlaying, let track = currentTrack {
            Task {
                try? await playTrack(track)
            }
        }
    }

    private func playTrack(_ track: Track) async throws {
        if spotifyService.isConnected {
            try await spotifyService.play(track: track)
        } else if appleMusicService.isConnected {
            try await appleMusicService.play(track: track)
        }
    }

    private func togglePlayback(track: Track) {
        Task {
            do {
                if isPlaying {
                    if spotifyService.isConnected {
                        try await spotifyService.pause()
                    } else if appleMusicService.isConnected {
                        try await appleMusicService.pause()
                    }
                } else {
                    if spotifyService.isConnected {
                        try await spotifyService.play(track: track)
                    } else if appleMusicService.isConnected {
                        try await appleMusicService.play(track: track)
                    }
                }
                isPlaying.toggle()
            } catch {
                print("Playback error: \(error.localizedDescription)")
            }
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
