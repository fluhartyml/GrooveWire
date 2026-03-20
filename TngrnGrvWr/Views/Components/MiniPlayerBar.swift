import SwiftUI

struct MiniPlayerBar: View {
    @Environment(PlaybackManager.self) private var playbackManager
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @State private var showDevicePicker = false

    var body: some View {
        if let track = playbackManager.currentTrack {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    // Artwork
                    if let urlString = track.artworkURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            artworkPlaceholder
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        artworkPlaceholder
                    }

                    // Track info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if let next = playbackManager.nextTrack {
                            Text("Next: \(next.title) — \(next.artist)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Transport controls
                    HStack(spacing: 16) {
                        Button { playbackManager.skipBackward() } label: {
                            Image(systemName: "backward.fill")
                                .font(.body)
                        }
                        .disabled(!playbackManager.canSkipBackward)

                        Button { playbackManager.togglePlayback() } label: {
                            Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title3)
                        }

                        Button { playbackManager.skipForward() } label: {
                            Image(systemName: "forward.fill")
                                .font(.body)
                        }
                        .disabled(!playbackManager.canSkipForward)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                    // Audio output
                    audioOutputButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Audio Output

    @ViewBuilder
    private var audioOutputButton: some View {
        if appleMusicService.isConnected {
            AirPlayButton()
                .frame(width: 28, height: 28)
        }

        if spotifyService.isConnected {
            Button { showDevicePicker = true } label: {
                Image(systemName: "hifispeaker.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDevicePicker) {
                VStack(spacing: 0) {
                    List {
                        SpotifyDevicePicker()
                    }
                    .listStyle(.plain)

                    Divider()

                    HStack {
                        Button("Cancel") {
                            showDevicePicker = false
                        }
                        Spacer()
                        Button("Select") {
                            showDevicePicker = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(spotifyService.selectedDeviceID == nil)
                    }
                    .padding(12)
                }
                .frame(minWidth: 280, minHeight: 250)
            }
        }
    }

    // MARK: - Helpers

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .frame(width: 40, height: 40)
            .overlay {
                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
    }
}
