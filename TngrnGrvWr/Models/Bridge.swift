import Foundation
import SwiftData

@Model
final class Bridge {
    var id: UUID = UUID()
    var name: String = ""
    var hostID: UUID = UUID()
    var isPublic: Bool = true
    var isActive: Bool = false
    var createdAt: Date = Date()

    // Role map: userID string → BridgeRole raw value
    var roles: [String: String] = [:]
    var bannedIDs: [String] = []

    @Relationship(deleteRule: .cascade) var tracks: [Track]?
    @Relationship(deleteRule: .cascade) var messages: [Message]?

    init(
        id: UUID = UUID(),
        name: String,
        hostID: UUID,
        isPublic: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.hostID = hostID
        self.isPublic = isPublic
        self.isActive = false
        self.createdAt = createdAt
        self.tracks = []
        self.messages = []
        self.roles = [hostID.uuidString: BridgeRole.host.rawValue]
        self.bannedIDs = []
    }

    // MARK: - Role Queries

    func role(for userID: UUID) -> BridgeRole? {
        guard let raw = roles[userID.uuidString] else { return nil }
        return BridgeRole(rawValue: raw)
    }

    func isHost(_ userID: UUID) -> Bool {
        role(for: userID) == .host
    }

    // MARK: - Role Assignment

    func setRole(_ userID: UUID, to newRole: BridgeRole) {
        guard newRole != .host else { return } // can't assign host
        roles[userID.uuidString] = newRole.rawValue
    }

    func promoteToCohost(_ userID: UUID) { setRole(userID, to: .cohost) }
    func promoteToBouncer(_ userID: UUID) { setRole(userID, to: .bouncer) }
    func demoteToParticipant(_ userID: UUID) { setRole(userID, to: .participant) }
    func demoteToListener(_ userID: UUID) { setRole(userID, to: .listener) }

    // MARK: - Permission Checks

    func canKick(_ userID: UUID) -> Bool {
        role(for: userID)?.canKick ?? false
    }

    func canBan(_ userID: UUID) -> Bool {
        role(for: userID)?.canBan ?? false
    }

    func canInvite(_ userID: UUID) -> Bool {
        role(for: userID)?.canInvite ?? false
    }

    func canAddTracks(_ userID: UUID) -> Bool {
        role(for: userID)?.canAddTracks ?? false
    }

    func canControlPlayback(_ userID: UUID) -> Bool {
        role(for: userID)?.canControlPlayback ?? false
    }

    func canManageRoles(_ userID: UUID) -> Bool {
        role(for: userID)?.canManageRoles ?? false
    }

    // MARK: - Bridge Controls

    func startBridge() { isActive = true }
    func stopBridge() { isActive = false }

    // MARK: - Membership

    func join(_ userID: UUID, as joinRole: BridgeRole = .participant) -> Bool {
        guard !isBanned(userID), role(for: userID) == nil else { return false }
        setRole(userID, to: joinRole)
        return true
    }

    func leave(_ userID: UUID) {
        guard !isHost(userID) else { return }
        roles.removeValue(forKey: userID.uuidString)
    }

    func kick(_ userID: UUID) {
        guard !isHost(userID) else { return }
        roles.removeValue(forKey: userID.uuidString)
    }

    func ban(_ userID: UUID) {
        kick(userID)
        if !bannedIDs.contains(userID.uuidString) {
            bannedIDs.append(userID.uuidString)
        }
    }

    func unban(_ userID: UUID) {
        bannedIDs.removeAll { $0 == userID.uuidString }
    }

    func isBanned(_ userID: UUID) -> Bool {
        bannedIDs.contains(userID.uuidString)
    }

    // MARK: - Computed

    /// Safe accessor for tracks (unwraps optional relationship)
    var trackList: [Track] {
        get { tracks ?? [] }
        set { tracks = newValue }
    }

    /// Safe accessor for messages (unwraps optional relationship)
    var messageList: [Message] {
        get { messages ?? [] }
        set { messages = newValue }
    }

    var memberIDs: [String] {
        Array(roles.keys)
    }

    var guestCount: Int {
        roles.count - 1 // exclude host
    }

    var participantCount: Int {
        roles.count
    }

    /// All members grouped by role, sorted by authority
    var membersByRole: [(role: BridgeRole, userIDs: [String])] {
        let grouped = Dictionary(grouping: roles) { BridgeRole(rawValue: $0.value) ?? .listener }
        return grouped
            .map { (role: $0.key, userIDs: $0.value.map(\.key)) }
            .sorted { $0.role < $1.role }
    }

    // Back-compat helpers used by BridgeView
    var guestIDs: [String] {
        roles.filter { $0.value != BridgeRole.host.rawValue }.map(\.key)
    }

    var bouncerIDs: [String] {
        roles.filter { $0.value == BridgeRole.bouncer.rawValue }.map(\.key)
    }

    var guestsCanInvite: Bool {
        isPublic
    }

    func isBouncer(_ userID: UUID) -> Bool {
        role(for: userID) == .bouncer
    }

    func demoteFromBouncer(_ userID: UUID) {
        demoteToParticipant(userID)
    }

    // MARK: - Vote-Sorted Queue

    /// Returns upcoming tracks sorted by vote weight.
    /// Pinned first → highest voteScore → normal → lowest voteScore → buried last.
    /// Ties preserve original add order (stable sort).
    func sortedUpcoming(after index: Int) -> [Track] {
        let allTracks = trackList
        guard allTracks.count > index + 1 else { return [] }
        let upcoming = Array(allTracks[(index + 1)...])

        return upcoming.sorted { a, b in
            // Pinned tracks always first
            if a.isPinned != b.isPinned { return a.isPinned }
            // Buried tracks always last
            if a.isBuried != b.isBuried { return b.isBuried }
            // Higher vote score comes first
            if a.voteScore != b.voteScore { return a.voteScore > b.voteScore }
            // Tie: preserve original order (earlier addedAt first)
            return a.addedAt < b.addedAt
        }
    }
}
