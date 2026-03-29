import SwiftUI

struct TrackRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            if let urlString = track.artworkURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    serviceBadges
                }
            }

            Spacer()

            Text(formattedDuration)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var serviceBadges: some View {
        HStack(spacing: 2) {
            if track.spotifyID != nil {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
            }
            if track.appleMusicID != nil {
                Image(systemName: "apple.logo")
                    .font(.system(size: 8))
                    .foregroundStyle(.pink)
            }
        }
    }

    private var formattedDuration: String {
        let minutes = Int(track.durationSeconds) / 60
        let seconds = Int(track.durationSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
