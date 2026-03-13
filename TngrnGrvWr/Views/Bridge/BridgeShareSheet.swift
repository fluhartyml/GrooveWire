import SwiftUI

struct BridgeShareSheet: View {
    let bridge: Bridge
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Share Bridge")
                    .font(.headline)

                BridgeTradingCard(bridge: bridge)
                    .padding()

                ShareLink(
                    item: "\(bridge.name) — \(bridge.tracks.count) tracks on Tangerine Grovewire",
                    preview: SharePreview(bridge.name, image: Image(systemName: "antenna.radiowaves.left.and.right"))
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
