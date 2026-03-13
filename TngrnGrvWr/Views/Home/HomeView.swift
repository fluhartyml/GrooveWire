import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Query(sort: \Bridge.createdAt, order: .reverse) private var bridges: [Bridge]

    private var hasService: Bool {
        spotifyService.isConnected || appleMusicService.isConnected
    }

    var body: some View {
        List {
            if !hasService {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.tv")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)

                        Text("Connect a Streaming Service")
                            .font(.headline)

                        Text("Head to the Profile tab to connect Spotify or Apple Music, then come back to start a GrooveWire bridge.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            }

            Section("Active Bridges") {
                if bridges.isEmpty {
                    ContentUnavailableView(
                        "No Bridges Yet",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text(hasService
                            ? "Go to the GrooveWire tab and tap + to create your first bridge."
                            : "Connect a streaming service first, then create a bridge.")
                    )
                } else {
                    ForEach(bridges) { bridge in
                        NavigationLink(destination: BridgeView(bridge: bridge)) {
                            BridgeCard(bridge: bridge)
                        }
                    }
                }
            }
        }
        .navigationTitle("Home")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
