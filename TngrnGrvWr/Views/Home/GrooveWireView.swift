import SwiftUI
import SwiftData

/// The GrooveWire tab — transfer and import workflows.
/// "Bridging the gap" between streaming services.
struct GrooveWireView: View {
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(\.themeColor) private var themeColor
    @State private var showImportPlaylist = false
    @State private var showSeedPlaylist = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // MARK: - Header
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 40))
                        .foregroundStyle(themeColor)

                    Text("GrooveWire")
                        .font(.title2.bold())

                    Text("Bridging the gap between streaming services")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                // MARK: - Services Status
                GroupBox("Connected Services") {
                    VStack(spacing: 8) {
                        serviceRow(
                            name: "Spotify",
                            icon: "dot.radiowaves.left.and.right",
                            connected: spotifyService.isConnected,
                            color: .green,
                            onDisconnect: { spotifyService.disconnect() }
                        )
                        Divider()
                        serviceRow(
                            name: "Apple Music",
                            icon: "apple.logo",
                            connected: appleMusicService.isConnected,
                            color: .mint,
                            onDisconnect: { appleMusicService.disconnect() }
                        )

                        if !spotifyService.isConnected && !appleMusicService.isConnected {
                            Text("Connect a service in your Profile to get started.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }

                // MARK: - Transfer Actions
                GroupBox("Transfer & Import") {
                    VStack(spacing: 12) {
                        Button {
                            showImportPlaylist = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.down")
                                    .foregroundStyle(themeColor)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Import Playlists or Songs")
                                        .font(.subheadline.weight(.medium))
                                    Text("Paste a Spotify link, import CSV/M3U, or browse Apple Music")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)

                        Divider()

                        Button {
                            showSeedPlaylist = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "wand.and.stars")
                                    .foregroundStyle(themeColor)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Build Playlist from Song")
                                        .font(.subheadline.weight(.medium))
                                    Text("Pick a seed song, get recommendations, save as playlist")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // MARK: - How It Works
                GroupBox("How It Works") {
                    VStack(alignment: .leading, spacing: 8) {
                        howItWorksRow(step: "1", text: "Import a playlist from Spotify, Apple Music, or a file")
                        howItWorksRow(step: "2", text: "GrooveWire matches every track across services")
                        howItWorksRow(step: "3", text: "Review matches — fix any near or unmatched tracks")
                        howItWorksRow(step: "4", text: "Transfer to your library or export as M3U")
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("GrooveWire")
        .sheet(isPresented: $showImportPlaylist) {
            ImportPlaylistSheet()
        }
        .sheet(isPresented: $showSeedPlaylist) {
            SeedPlaylistSheet()
        }
    }

    // MARK: - Helpers

    private func serviceRow(name: String, icon: String, connected: Bool, color: Color, onDisconnect: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(connected ? color : .secondary)
                .frame(width: 20)
            Text(name)
                .font(.subheadline)
            Spacer()
            if connected {
                Text("Connected")
                    .font(.caption)
                    .foregroundStyle(color)
                Button {
                    onDisconnect()
                } label: {
                    Image(systemName: "circle.slash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Disconnect")
            } else {
                Text("Not Connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func howItWorksRow(step: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(step)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(themeColor, in: Circle())
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        GrooveWireView()
    }
}
