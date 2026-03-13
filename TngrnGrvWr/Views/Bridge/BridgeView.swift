import SwiftUI
import SwiftData

struct BridgeView: View {
    let bridge: Bridge

    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @State private var showSearch = false
    @State private var showShare = false
    @State private var isPlaying = false

    var body: some View {
        List {
            nowPlayingSection
            queueSection
        }
        .navigationTitle(bridge.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showSearch = true } label: {
                        Label("Add Tracks", systemImage: "plus")
                    }
                    Button { showShare = true } label: {
                        Label("Share Bridge", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            SearchView(bridge: bridge)
        }
        .sheet(isPresented: $showShare) {
            BridgeShareSheet(bridge: bridge)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var nowPlayingSection: some View {
        Section("Now Playing") {
            if let currentTrack = bridge.tracks.first {
                NowPlayingRow(track: currentTrack)
                playbackControls(for: currentTrack)
            } else {
                Text("Nothing playing")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var queueSection: some View {
        Section("Queue (\(max(bridge.tracks.count - 1, 0)))") {
            if bridge.tracks.count > 1 {
                ForEach(Array(bridge.tracks.dropFirst())) { track in
                    TrackRow(track: track)
                }
            } else {
                Text("Queue is empty — tap + to add tracks")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Playback

    @ViewBuilder
    private func playbackControls(for track: Track) -> some View {
        HStack(spacing: 32) {
            Spacer()

            Button { } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }

            Button { togglePlayback(track: track) } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
            }

            Button { } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }

            Spacer()
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
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
