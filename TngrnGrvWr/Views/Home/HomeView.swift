import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Query(sort: \SavedPlaylist.createdAt, order: .reverse) private var playlists: [SavedPlaylist]
    @Environment(\.themeColor) private var themeColor
    @State private var showProfile = false
    @State private var showFAQ = false

    private var totalTracks: Int {
        playlists.reduce(0) { $0 + $1.trackCount }
    }

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
                .foregroundStyle(themeColor)
        }
        #else
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
        #endif
    }

    var body: some View {
        ScrollView {
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

                    Text("Bridging the gap")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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

                // MARK: - Quick Stats
                GroupBox("At a Glance") {
                    HStack {
                        statCard(value: playlists.count, label: "Playlists", icon: "music.note.list")
                        Divider()
                        statCard(value: totalTracks, label: "Tracks", icon: "music.note")
                        Divider()
                        statCard(
                            value: playlists.filter { $0.spotifyPlaylistID != nil }.count,
                            label: "Spotify",
                            icon: "dot.radiowaves.left.and.right"
                        )
                        Divider()
                        statCard(
                            value: playlists.filter { $0.appleMusicPlaylistID != nil }.count,
                            label: "Apple Music",
                            icon: "apple.logo"
                        )
                    }
                    .padding(.vertical, 4)
                }

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
                    }
                }

                // MARK: - Quick Actions
                GroupBox("Quick Actions") {
                    VStack(spacing: 8) {
                        Button {
                            showProfile = true
                        } label: {
                            actionRow(icon: "person.fill", title: "Profile", subtitle: "Manage your account and service connections")
                        }
                        .buttonStyle(.plain)

                        Divider()

                        Button {
                            showFAQ = true
                        } label: {
                            actionRow(icon: "questionmark.circle", title: "Support", subtitle: "FAQ and help documentation")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Home")
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showProfile = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showFAQ) {
            NavigationStack {
                FAQView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showFAQ = false }
                        }
                    }
            }
        }
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
                .foregroundStyle(themeColor)
            Text("\(value)")
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(themeColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
