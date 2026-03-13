import SwiftUI
import MusicKit

struct ProfileView: View {
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @State private var showSpotifyLogin = false

    var body: some View {
        List {
            Section("Streaming Services") {
                spotifyRow
                appleMusicRow
            }

            Section("About") {
                Label("Tangerine Grovewire", systemImage: "antenna.radiowaves.left.and.right")
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showSpotifyLogin) {
            SpotifyLoginView(authManager: spotifyService.authManager)
        }
    }

    @ViewBuilder
    private var spotifyRow: some View {
        if spotifyService.isConnected {
            HStack {
                Label("Spotify", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .swipeActions {
                Button("Disconnect", role: .destructive) {
                    spotifyService.disconnect()
                }
            }
        } else {
            Button {
                showSpotifyLogin = true
            } label: {
                Label("Connect Spotify", systemImage: "dot.radiowaves.left.and.right")
            }
        }
    }

    @ViewBuilder
    private var appleMusicRow: some View {
        if appleMusicService.isConnected {
            HStack {
                Label("Apple Music", systemImage: "apple.logo")
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .swipeActions {
                Button("Disconnect", role: .destructive) {
                    appleMusicService.disconnect()
                }
            }
        } else {
            Button {
                Task { try? await appleMusicService.connect() }
            } label: {
                Label("Connect Apple Music", systemImage: "apple.logo")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
