import SwiftUI

struct BridgeShareSheet: View {
    let bridge: Bridge
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var inviteLink: String {
        "tngrnGrvWr://bridge/\(bridge.id.uuidString)"
    }

    private var shareText: String {
        "Join my GrooveWire bridge \"\(bridge.name)\"! \(bridge.tracks.count) tracks queued up.\n\(inviteLink)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Share Bridge")
                    .font(.headline)

                BridgeTradingCard(bridge: bridge)
                    .padding()

                GroupBox("Invite Link") {
                    HStack {
                        Text(inviteLink)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = inviteLink
                            #else
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(inviteLink, forType: .string)
                            #endif
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copied = false
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .foregroundStyle(copied ? .green : .accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                ShareLink(
                    item: shareText,
                    preview: SharePreview(bridge.name, image: Image(systemName: "antenna.radiowaves.left.and.right"))
                ) {
                    Label("Send Invite", systemImage: "paperplane.fill")
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
