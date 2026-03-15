import SwiftUI
import SwiftData

struct SavedPlaylistDetailView: View {
    let playlist: SavedPlaylist

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bridge.createdAt, order: .reverse) private var bridges: [Bridge]
    @State private var showBridgePicker = false

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
        .sheet(isPresented: $showBridgePicker) {
            BridgePickerSheet(tracks: playlist.trackList, bridges: bridges) { bridge in
                for track in playlist.trackList {
                    bridge.trackList.append(track)
                }
                try? modelContext.save()
            }
        }
    }
}
