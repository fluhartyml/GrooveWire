import Foundation

enum BridgeRole: String, Codable, Comparable {
    case host
    case cohost
    case bouncer
    case participant
    case listener

    var displayName: String {
        switch self {
        case .host: "Host"
        case .cohost: "Co-Host"
        case .bouncer: "Bouncer"
        case .participant: "Participant"
        case .listener: "Listener"
        }
    }

    var iconName: String {
        switch self {
        case .host: "crown.fill"
        case .cohost: "crown"
        case .bouncer: "shield.checkered"
        case .participant: "person.fill"
        case .listener: "headphones"
        }
    }

    // Permissions

    var canKick: Bool { self <= .bouncer }
    var canBan: Bool { self <= .cohost }
    var canInvite: Bool { self <= .participant }
    var canAddTracks: Bool { self <= .participant }
    var canChat: Bool { self <= .participant }
    var canControlPlayback: Bool { self <= .cohost }
    var canManageRoles: Bool { self <= .cohost }
    var canRenameBridge: Bool { self <= .cohost }

    // Comparable — lower raw index = higher authority
    private var authorityLevel: Int {
        switch self {
        case .host: 0
        case .cohost: 1
        case .bouncer: 2
        case .participant: 3
        case .listener: 4
        }
    }

    static func < (lhs: BridgeRole, rhs: BridgeRole) -> Bool {
        lhs.authorityLevel < rhs.authorityLevel
    }
}
