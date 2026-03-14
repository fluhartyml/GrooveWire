import SwiftUI

struct MembersSheet: View {
    let bridge: Bridge
    @Environment(\.dismiss) private var dismiss
    @State private var expandedMember: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(bridge.membersByRole, id: \.role) { group in
                    Section {
                        ForEach(group.userIDs, id: \.self) { userID in
                            memberRow(userID: userID, role: group.role)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: group.role.iconName)
                                .foregroundStyle(group.role.roleColor)
                                .font(.caption)
                            Text(group.role.displayName)
                        }
                    }
                }
            }
            .navigationTitle("Members")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Member Row

    @ViewBuilder
    private func memberRow(userID: String, role: BridgeRole) -> some View {
        let isExpanded = expandedMember == userID
        let displayName = String(userID.prefix(8)) + "..."

        VStack(spacing: 0) {
            // Main row — mini avatar + name + role badge
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedMember = isExpanded ? nil : userID
                }
            } label: {
                HStack(spacing: 12) {
                    // Mini avatar
                    MemberAvatar(
                        name: displayName,
                        role: role,
                        size: isExpanded ? 56 : 36
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(isExpanded ? .headline : .body)
                            .foregroundStyle(.primary)
                        Text(role.displayName)
                            .font(.caption)
                            .foregroundStyle(role.roleColor)
                    }

                    Spacer()

                    Image(systemName: role.iconName)
                        .foregroundStyle(role.roleColor)
                        .font(.caption)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded actions
            if isExpanded, role != .host {
                Divider()
                    .padding(.vertical, 8)

                roleActions(userID: userID, currentRole: role)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }

    // MARK: - Role Actions

    @ViewBuilder
    private func roleActions(userID: String, currentRole: BridgeRole) -> some View {
        VStack(spacing: 8) {
            // Role change buttons — horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if currentRole != .cohost {
                        roleButton("Co-Host", icon: "crown", color: BridgeRole.cohost.roleColor) {
                            if let uuid = UUID(uuidString: userID) { bridge.promoteToCohost(uuid) }
                        }
                    }
                    if currentRole != .bouncer {
                        roleButton("Bouncer", icon: "shield.checkered", color: BridgeRole.bouncer.roleColor) {
                            if let uuid = UUID(uuidString: userID) { bridge.promoteToBouncer(uuid) }
                        }
                    }
                    if currentRole != .participant {
                        roleButton("Participant", icon: "person.fill", color: BridgeRole.participant.roleColor) {
                            if let uuid = UUID(uuidString: userID) { bridge.demoteToParticipant(uuid) }
                        }
                    }
                    if currentRole != .listener {
                        roleButton("Listener", icon: "headphones", color: BridgeRole.listener.roleColor) {
                            if let uuid = UUID(uuidString: userID) { bridge.demoteToListener(uuid) }
                        }
                    }
                }
            }

            // Destructive actions
            HStack(spacing: 12) {
                Button {
                    if let uuid = UUID(uuidString: userID) { bridge.kick(uuid) }
                    expandedMember = nil
                } label: {
                    Label("Kick", systemImage: "hand.raised")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.red.opacity(0.8), in: Capsule())
                }

                Button {
                    if let uuid = UUID(uuidString: userID) { bridge.ban(uuid) }
                    expandedMember = nil
                } label: {
                    Label("Ban", systemImage: "xmark.shield")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.red, in: Capsule())
                }

                Spacer()
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func roleButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            expandedMember = nil
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Member Avatar

struct MemberAvatar: View {
    let name: String
    let role: BridgeRole
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(role.roleColor.opacity(0.2))
                .frame(width: size, height: size)

            Circle()
                .strokeBorder(role.roleColor, lineWidth: size > 40 ? 2 : 1.5)
                .frame(width: size, height: size)

            // Initials or icon
            if name.count >= 2 {
                Text(String(name.prefix(2)).uppercased())
                    .font(.system(size: size * 0.35, weight: .semibold, design: .rounded))
                    .foregroundStyle(role.roleColor)
            } else {
                Image(systemName: role.iconName)
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(role.roleColor)
            }
        }
    }
}

#Preview {
    MembersSheet(bridge: Bridge(name: "Test Bridge", hostID: UUID()))
}
