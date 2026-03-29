import SwiftUI
import SwiftData

struct PlaylistShareSheet: View {
    let playlist: SavedPlaylist
    @Environment(\.themeColor) private var themeColor
    @Environment(\.dismiss) private var dismiss
    @State private var copiedLink = false

    private var shareText: String {
        let trackPreview = playlist.trackList.prefix(5)
            .enumerated()
            .map { "\($0.offset + 1). \($0.element.artist) — \($0.element.title)" }
            .joined(separator: "\n")
        let more = playlist.trackList.count > 5 ? "\n+ \(playlist.trackList.count - 5) more" : ""
        var text = "Check out \"\(playlist.name)\"! \(playlist.trackList.count) tracks.\n\n\(trackPreview)\(more)"
        if let spotifyID = playlist.spotifyPlaylistID {
            text += "\n\nhttps://open.spotify.com/playlist/\(spotifyID)"
        }
        return text
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Share Playlist")
                    .font(.headline)

                PlaylistTradingCard(playlist: playlist)
                    .padding()

                // Share via system share sheet
                ShareLink(
                    item: shareText,
                    preview: SharePreview(playlist.name, image: Image(systemName: "music.note.list"))
                ) {
                    Label("Send to Friends", systemImage: "paperplane.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // Copy Spotify link if available
                if let spotifyID = playlist.spotifyPlaylistID {
                    Button {
                        let link = "https://open.spotify.com/playlist/\(spotifyID)"
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(link, forType: .string)
                        #else
                        UIPasteboard.general.string = link
                        #endif
                        copiedLink = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedLink = false
                        }
                    } label: {
                        Label(copiedLink ? "Copied!" : "Copy Spotify Link",
                              systemImage: copiedLink ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(copiedLink ? .green : nil)
                    .padding(.horizontal)
                }

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
