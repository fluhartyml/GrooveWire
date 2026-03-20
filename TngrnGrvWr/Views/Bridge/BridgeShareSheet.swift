import SwiftUI
import SwiftData

struct BridgeShareSheet: View {
    let bridge: Bridge
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    @State private var copied = false
    @State private var inviteeAge: AgeCategory = .adult

    private var currentUser: User? { users.first }

    private var inviteLink: String {
        "tngrnGrvWr://bridge/\(bridge.id.uuidString)"
    }

    private var shareText: String {
        "Join my GrooveWire bridge \"\(bridge.name)\"! \(bridge.trackList.count) tracks queued up.\n\(inviteLink)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Share Bridge")
                    .font(.headline)

                BridgeTradingCard(bridge: bridge)
                    .padding()

                GroupBox("Invitee Age") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Age Group", selection: $inviteeAge) {
                            Text("18+").tag(AgeCategory.adult)
                            Text("13-17").tag(AgeCategory.teen)
                            Text("Under 13").tag(AgeCategory.child)
                        }
                        .pickerStyle(.segmented)

                        ageNotice
                    }
                }
                .padding(.horizontal)

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

    @ViewBuilder
    private var ageNotice: some View {
        switch inviteeAge {
        case .child:
            Label("Under 13 — they will be anonymous in the bridge", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .teen:
            Label("13-17 — private by default, screen name hidden unless they have parental consent", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.blue)
        case .adult:
            Label("18+ — full profile visibility", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.green)
        case .unknown:
            EmptyView()
        }
    }
}
