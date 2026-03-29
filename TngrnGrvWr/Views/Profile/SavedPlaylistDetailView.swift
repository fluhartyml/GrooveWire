import SwiftUI
import SwiftData

struct SavedPlaylistDetailView: View {
    let playlist: SavedPlaylist

    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Environment(AppleMusicService.self) private var appleMusicService
    @State private var showTransferSheet = false
    @State private var showExportSheet = false
    @State private var showMusicTransferSheet = false
    @State private var showShareSheet = false

    private var canTransferToMusic: Bool {
        #if os(macOS)
        let hasSpotifyTracks = playlist.trackList.contains(where: { $0.spotifyID != nil })
        return hasSpotifyTracks && appleMusicService.isConnected
        #else
        return false
        #endif
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "music.note.list")
                        .font(.largeTitle)
                        .foregroundStyle(themeColor)
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
                #if os(macOS)
                if canTransferToMusic {
                    Button {
                        showMusicTransferSheet = true
                    } label: {
                        Label("Transfer to Apple Music", systemImage: "apple.logo")
                    }
                    .disabled(playlist.trackList.isEmpty)
                }
                #endif

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

                Button {
                    showShareSheet = true
                } label: {
                    Label("Share Playlist", systemImage: "paperplane")
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
        .sheet(isPresented: $showExportSheet) {
            M3UExportSheet(playlist: playlist)
        }
        .sheet(isPresented: $showMusicTransferSheet) {
            PlaylistTransferToMusicSheet(playlist: playlist)
        }
        .sheet(isPresented: $showShareSheet) {
            PlaylistShareSheet(playlist: playlist)
        }
    }
}
