import SwiftUI

struct BridgeCard: View {
    let bridge: Bridge

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(bridge.name)
                .font(.headline)

            HStack(spacing: 8) {
                Label("\(bridge.trackList.count)", systemImage: "music.note.list")
                Label("\(bridge.participantCount)", systemImage: "person.2")
                if bridge.isPublic {
                    Label("Public", systemImage: "globe")
                } else {
                    Label("Private", systemImage: "lock.fill")
                }
                if bridge.isActive {
                    Text("LIVE")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
