import SwiftUI
import SwiftData

#if os(macOS)
import AppKit
#endif

struct M3UExportSheet: View {
    let playlist: SavedPlaylist
    @Environment(TrackMatchingService.self) private var trackMatchingService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor

    @State private var isMatching = false
    @State private var matchedCount = 0
    @State private var m3uURL: URL?
    @State private var copiedLink = false

    private var needsMatching: Bool {
        appleMusicService.isConnected &&
        playlist.trackList.contains(where: { $0.spotifyID != nil && $0.appleMusicID == nil })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundStyle(themeColor)

                Text(playlist.name)
                    .font(.headline)

                Text("\(playlist.trackCount) tracks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if isMatching {
                    VStack(spacing: 8) {
                        ProgressView(value: trackMatchingService.matchProgress)
                            .tint(themeColor)
                        Text("Matching tracks to Apple Music...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                } else if matchedCount > 0 {
                    Label("\(matchedCount) tracks matched to Apple Music", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Divider()

                if let m3uURL {
                    #if os(macOS)
                    Button {
                        let musicAppURL = URL(fileURLWithPath: "/System/Applications/Music.app")
                        NSWorkspace.shared.open([m3uURL], withApplicationAt: musicAppURL, configuration: NSWorkspace.OpenConfiguration())
                        dismiss()
                    } label: {
                        Label("Open in Music", systemImage: "music.note")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeColor)
                    #endif

                    ShareLink(
                        item: m3uURL,
                        preview: SharePreview(playlist.name, image: Image(systemName: "music.note.list"))
                    ) {
                        Label("Share via AirDrop / Messages", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

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
                    } label: {
                        Label(copiedLink ? "Copied!" : "Copy Spotify Link",
                              systemImage: copiedLink ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(copiedLink ? .green : nil)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Export Playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 300)
        .task {
            if needsMatching {
                await matchTracks()
            }
            m3uURL = generateM3U()
        }
    }

    private func matchTracks() async {
        let tracksToMatch = playlist.trackList.filter { $0.spotifyID != nil && $0.appleMusicID == nil }
        guard !tracksToMatch.isEmpty else { return }

        isMatching = true
        let results = await trackMatchingService.matchPlaylist(tracksToMatch, to: .appleMusic)

        var matched = 0
        for result in results {
            if let matchedTrack = result.matchedTrack, let appleID = matchedTrack.appleMusicID {
                result.originalTrack.appleMusicID = appleID
                result.originalTrack.matchConfidence = result.confidence
                matched += 1
            }
        }

        if matched > 0 {
            try? modelContext.save()
        }

        matchedCount = matched
        isMatching = false
    }

    private func generateM3U() -> URL {
        var m3u = "#EXTM3U\n"
        for track in playlist.trackList {
            let duration = Int(track.durationSeconds)
            m3u += "#EXTINF:\(duration),\(track.artist) - \(track.title)\n"
            if let appleMusicID = track.appleMusicID {
                m3u += "https://music.apple.com/song/\(appleMusicID)\n"
            } else if let spotifyID = track.spotifyID {
                m3u += "https://open.spotify.com/track/\(spotifyID)\n"
            } else {
                m3u += "\(track.artist) - \(track.title).mp3\n"
            }
        }
        let filename = playlist.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).m3u")
        try? m3u.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
