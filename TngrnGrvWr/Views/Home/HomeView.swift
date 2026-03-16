import SwiftUI
import SwiftData

struct HomeView: View {
    var onBridgeTap: ((UUID) -> Void)?

    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Query(sort: \Bridge.createdAt, order: .reverse) private var bridges: [Bridge]
    @Query(sort: \SavedPlaylist.createdAt, order: .reverse) private var playlists: [SavedPlaylist]

    @ViewBuilder
    private var appIconImage: some View {
        #if os(iOS)
        if let uiImage = UIImage(named: "AppIcon") {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
        }
        #else
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
        #endif
    }

    private var activeBridges: [Bridge] {
        bridges.filter { $0.isActive }
    }

    private var totalTracks: Int {
        bridges.reduce(0) { $0 + $1.trackList.count }
    }

    var body: some View {
        VStack(spacing: 16) {
                // MARK: - Hero
                VStack(spacing: 8) {
                    appIconImage
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .shadow(radius: 6, y: 3)

                    Text("GrooveWire")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    HStack(spacing: 4) {
                        Image("ClaudeLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Text("Engineered with Claude by Anthropic")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 12)

                // MARK: - Services
                GroupBox("Streaming Services") {
                    VStack(spacing: 8) {
                        serviceRow(
                            name: "Spotify",
                            icon: "dot.radiowaves.left.and.right",
                            connected: spotifyService.isConnected,
                            color: .green
                        )
                        Divider()
                        serviceRow(
                            name: "Apple Music",
                            icon: "apple.logo",
                            connected: appleMusicService.isConnected,
                            color: .mint
                        )

                        if !spotifyService.isConnected && !appleMusicService.isConnected {
                            Text("Head to the Profile tab to connect a service.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }

                // MARK: - Quick Stats
                GroupBox("At a Glance") {
                    HStack {
                        statCard(value: bridges.count, label: "Bridges", icon: "antenna.radiowaves.left.and.right")
                        Divider()
                        statCard(value: activeBridges.count, label: "Active", icon: "bolt.fill")
                        Divider()
                        statCard(value: totalTracks, label: "Tracks", icon: "music.note")
                        Divider()
                        statCard(value: playlists.count, label: "Playlists", icon: "music.note.list")
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Now Listening
                if let activeBridge = activeBridges.first {
                    GroupBox("Now Listening") {
                        VStack(spacing: 8) {
                            Button {
                                onBridgeTap?(activeBridge.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "waveform")
                                        .font(.title2)
                                        .foregroundStyle(.orange)
                                        .symbolEffect(.variableColor.iterative)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(activeBridge.name)
                                            .font(.headline)
                                        if let track = activeBridge.trackList.first {
                                            Text("\(track.artist) — \(track.title)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        Text("\(activeBridge.participantCount) listening")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)

                            ForEach(activeBridges.dropFirst().prefix(2)) { bridge in
                                Divider()
                                Button {
                                    onBridgeTap?(bridge.id)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "waveform")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                        VStack(alignment: .leading) {
                                            Text(bridge.name)
                                                .font(.subheadline)
                                            Text("\(bridge.participantCount) listening")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // MARK: - Recent Bridges
                if !bridges.isEmpty && activeBridges.isEmpty {
                    GroupBox("Recent Bridges") {
                        VStack(spacing: 8) {
                            ForEach(Array(bridges.prefix(3).enumerated()), id: \.element.id) { index, bridge in
                                if index > 0 { Divider() }
                                Button {
                                    onBridgeTap?(bridge.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(bridge.name)
                                                .font(.subheadline)
                                            Text("\(bridge.trackList.count) tracks · \(bridge.participantCount) members")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(bridge.createdAt, style: .relative)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        .padding(.horizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationTitle("Home")
    }

    // MARK: - Helpers

    private func serviceRow(name: String, icon: String, connected: Bool, color: Color) -> some View {
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
            } else {
                Text("Not Connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func statCard(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
