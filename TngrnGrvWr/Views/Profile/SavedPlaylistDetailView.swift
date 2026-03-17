import SwiftUI
import SwiftData

struct SavedPlaylistDetailView: View {
    let playlist: SavedPlaylist

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bridge.createdAt, order: .reverse) private var bridges: [Bridge]
    @State private var showBridgePicker = false
    @State private var showTransferSheet = false
    @State private var showExportSheet = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "music.note.list")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                        .frame(width: 80, height: 80)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.name)
                            .font(.title3.bold())
                        if let desc = playlist.playlistDescription, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 8) {
                            Label("\(playlist.trackCount)", systemImage: "music.note")
                            if playlist.spotifyPlaylistID != nil {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .foregroundStyle(.green)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    showBridgePicker = true
                } label: {
                    Label("Load into Bridge", systemImage: "antenna.radiowaves.left.and.right")
                }
                .disabled(playlist.trackList.isEmpty)

                Button {
                    showTransferSheet = true
                } label: {
                    Label("Transfer to Other Service", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(playlist.trackList.isEmpty)

                Button {
                    showExportSheet = true
                } label: {
                    Label("Export Playlist", systemImage: "square.and.arrow.up")
                }
                .disabled(playlist.trackList.isEmpty)
            }

            Section("Tracks") {
                if playlist.trackList.isEmpty {
                    Text("No tracks")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(playlist.trackList) { track in
                        TrackRow(track: track)
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showTransferSheet) {
            PlaylistTransferSheet(playlist: playlist)
        }
        .sheet(isPresented: $showBridgePicker) {
            BridgePickerSheet(tracks: playlist.trackList, bridges: bridges) { bridge in
                for track in playlist.trackList {
                    bridge.trackList.append(track)
                }
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $showExportSheet) {
            M3UExportSheet(playlist: playlist, m3uURL: m3uFileURL(for: playlist))
        }
    }

    private func m3uFileURL(for playlist: SavedPlaylist) -> URL {
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
