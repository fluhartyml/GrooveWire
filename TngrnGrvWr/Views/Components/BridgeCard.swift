import SwiftUI

struct BridgeCard: View {
    let bridge: Bridge
    @Environment(\.themeColor) private var themeColor

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
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeColor.opacity(0.2))
                .strokeBorder(themeColor.opacity(0.5), lineWidth: 1.5)
        )
    }
}
