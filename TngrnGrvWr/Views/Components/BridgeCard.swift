import SwiftUI

struct BridgeCard: View {
    let bridge: Bridge

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bridge.name)
                .font(.headline)

            HStack(spacing: 8) {
                Label("\(bridge.tracks.count)", systemImage: "music.note.list")
                if bridge.isPublic {
                    Label("Public", systemImage: "globe")
                } else {
                    Label("Private", systemImage: "lock.fill")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
