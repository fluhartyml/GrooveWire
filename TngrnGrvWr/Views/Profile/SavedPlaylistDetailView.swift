import SwiftUI
import SwiftData

struct SavedPlaylistDetailView: View {
    let playlist: SavedPlaylist
    var onBridgeCreated: ((UUID) -> Void)?

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
                    createBridgeFromPlaylist()
                } label: {
                    Label("Create Bridge from Playlist", systemImage: "plus.circle")
                }
                .disabled(playlist.trackList.isEmpty)

                Button {
                    showBridgePicker = true
                } label: {
                    Label("Load into Existing Bridge", systemImage: "antenna.radiowaves.left.and.right")
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
            M3UExportSheet(playlist: playlist)
        }
    }

    private func createBridgeFromPlaylist() {
        let bridge = Bridge(
            name: playlist.name,
            hostID: UUID(),
            isPublic: false
        )
        modelContext.insert(bridge)

        for track in playlist.trackList {
            let bridgeTrack = Track(
                title: track.title,
                artist: track.artist,
                albumTitle: track.albumTitle,
                artworkURL: track.artworkURL,
                appleMusicID: track.appleMusicID,
                spotifyID: track.spotifyID,
                durationSeconds: track.durationSeconds,
                addedBy: UUID()
            )
            modelContext.insert(bridgeTrack)
            bridge.trackList.append(bridgeTrack)
        }

        try? modelContext.save()
        print("[Library] Created bridge '\(playlist.name)' with \(playlist.trackCount) tracks")
        onBridgeCreated?(bridge.id)
    }
}
