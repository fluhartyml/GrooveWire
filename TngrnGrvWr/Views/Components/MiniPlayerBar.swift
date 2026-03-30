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

                    // LCD Display
                    lcdDisplay(track: track)

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

    // MARK: - LCD Display

    @ViewBuilder
    private func lcdDisplay(track: Track) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            // Line 1: Track title
            Text(track.title)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .lineLimit(1)

            // Line 2: Artist
            Text(track.artist)
                .font(.system(.caption2, design: .monospaced))
                .lineLimit(1)

            // Line 3: Status line — skip message, service icon, or next track
            if let skipped = playbackManager.skippedMessage {
                HStack(spacing: 4) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 7))
                    Text(skipped)
                        .font(.system(.caption2, design: .monospaced))
                }
                .foregroundStyle(.orange)
                .lineLimit(1)
            } else {
                HStack(spacing: 4) {
                    // Service indicator
                    if track.spotifyID != nil && track.appleMusicID != nil {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 7))
                            .foregroundStyle(.green)
                        Image(systemName: "apple.logo")
                            .font(.system(size: 7))
                            .foregroundStyle(.gray)
                    } else if track.spotifyID != nil {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 7))
                            .foregroundStyle(.green)
                    } else if track.appleMusicID != nil {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 7))
                            .foregroundStyle(.gray)
                    }

                    if let next = playbackManager.nextTrack {
                        Text("\(next.title) — \(next.artist)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5)
        )
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
