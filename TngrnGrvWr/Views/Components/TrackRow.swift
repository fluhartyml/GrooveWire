import SwiftUI

struct TrackRow: View {
    let track: Track

    // Optional voting — nil means no vote buttons shown (used outside bridges)
    var currentUserID: UUID? = nil
    var onVoteUp: (() -> Void)? = nil
    var onVoteDown: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Pin/bury indicator
            if track.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            } else if track.isBuried {
                Image(systemName: "arrow.down.to.line")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

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

                    // Service availability badges
                    serviceBadges
                }
            }

            Spacer()

            // Vote buttons (only shown in bridge context)
            if let onVoteUp, let onVoteDown {
                voteButtons(onUp: onVoteUp, onDown: onVoteDown)
            }

            Text(formattedDuration)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Service Badges

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

    // MARK: - Vote Buttons

    @ViewBuilder
    private func voteButtons(onUp: @escaping () -> Void, onDown: @escaping () -> Void) -> some View {
        let userVote = currentUserID.flatMap { track.userVote($0) }

        HStack(spacing: 4) {
            Button {
                onUp()
            } label: {
                Image(systemName: userVote == true ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.caption)
                    .foregroundStyle(userVote == true ? .green : .secondary)
            }
            .buttonStyle(.plain)

            if track.voteScore != 0 {
                Text("\(track.voteScore)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(track.voteScore > 0 ? .green : .red)
                    .monospacedDigit()
            }

            Button {
                onDown()
            } label: {
                Image(systemName: userVote == false ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.caption)
                    .foregroundStyle(userVote == false ? .red : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var formattedDuration: String {
        let minutes = Int(track.durationSeconds) / 60
        let seconds = Int(track.durationSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
