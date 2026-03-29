import SwiftUI

struct PlaylistTradingCard: View {
    let playlist: SavedPlaylist
    @Environment(\.themeColor) private var themeColor

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.title)
                    .foregroundStyle(themeColor)

                Text(playlist.name)
                    .font(.title2.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)

            // Album art grid (2x2)
            artworkGrid
                .padding(20)

            // Track list preview
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(playlist.trackList.prefix(4).enumerated()), id: \.offset) { index, track in
                    HStack {
                        Text("\(index + 1).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("\(track.artist) — \(track.title)")
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                if playlist.trackList.count > 4 {
                    Text("+ \(playlist.trackList.count - 4) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Footer
            HStack {
                Text("\(playlist.trackList.count) tracks")
                    .font(.caption2)
                Spacer()
                Text("Tangerine GrooveWire")
                    .font(.caption2.bold())
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 320, height: 420)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(themeColor.opacity(0.4), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var artworkGrid: some View {
        let artworks = playlist.trackList.prefix(4).compactMap { $0.artworkURL }
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                if index < artworks.count, let url = URL(string: artworks[index]) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        artworkPlaceholder
                    }
                    .frame(width: 130, height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    artworkPlaceholder
                }
            }
        }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .frame(width: 130, height: 130)
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.tertiary)
            }
    }
}

// MARK: - Render to Image (for sharing)

extension PlaylistTradingCard {
    @MainActor
    func renderToImage() -> Image? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3.0
        guard let cgImage = renderer.cgImage else { return nil }
        #if os(iOS)
        return Image(uiImage: UIImage(cgImage: cgImage))
        #else
        return Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)))
        #endif
    }
}
