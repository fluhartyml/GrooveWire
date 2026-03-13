import SwiftUI
import SwiftData

struct BridgeView: View {
    let bridge: Bridge

    var body: some View {
        List {
            Section("Now Playing") {
                if let currentTrack = bridge.tracks.first {
                    TrackRow(track: currentTrack)
                } else {
                    Text("Nothing playing")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Queue") {
                if bridge.tracks.count > 1 {
                    ForEach(bridge.tracks.dropFirst()) { track in
                        TrackRow(track: track)
                    }
                } else {
                    Text("Queue is empty")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(bridge.name)
    }
}

#Preview {
    NavigationStack {
        BridgeView(bridge: Bridge(name: "Chill Vibes", hostID: UUID()))
    }
}
