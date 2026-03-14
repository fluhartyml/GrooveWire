import Foundation
import SwiftData

@Model
final class Track {
    var id: UUID = UUID()
    var title: String = ""
    var artist: String = ""
    var albumTitle: String?
    var artworkURL: String?
    var appleMusicID: String?
    var spotifyID: String?
    var durationSeconds: Double = 0
    var addedBy: UUID = UUID()
    var addedAt: Date = Date()

    // Voting
    var voteScore: Int = 0
    var voterIDs: [String: Bool] = [:]  // userID string → true=up, false=down
    var isPinned: Bool = false           // host forced to top of queue
    var isBuried: Bool = false           // host forced to bottom of queue

    var bridge: Bridge?
    var savedPlaylist: SavedPlaylist?

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        albumTitle: String? = nil,
        artworkURL: String? = nil,
        appleMusicID: String? = nil,
        spotifyID: String? = nil,
        durationSeconds: Double = 0,
        addedBy: UUID,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.artworkURL = artworkURL
        self.appleMusicID = appleMusicID
        self.spotifyID = spotifyID
        self.durationSeconds = durationSeconds
        self.addedBy = addedBy
        self.addedAt = addedAt
    }

    // MARK: - Voting

    /// Cast or change a vote. One vote per user — replaces any previous vote.
    func vote(userID: UUID, isUpvote: Bool) {
        let key = userID.uuidString
        let existing = voterIDs[key]

        // Remove previous vote effect
        if let was = existing {
            voteScore += was ? -1 : 1
        }

        // Apply new vote
        voterIDs[key] = isUpvote
        voteScore += isUpvote ? 1 : -1
    }

    /// Remove a user's vote entirely.
    func removeVote(userID: UUID) {
        let key = userID.uuidString
        guard let was = voterIDs.removeValue(forKey: key) else { return }
        voteScore += was ? -1 : 1
    }

    /// Check how a user voted (nil = no vote).
    func userVote(_ userID: UUID) -> Bool? {
        voterIDs[userID.uuidString]
    }

    // MARK: - Host Override

    /// Pin this track to play next (host override).
    func pin() {
        isPinned = true
        isBuried = false
    }

    /// Bury this track to play last (host override).
    func bury() {
        isBuried = true
        isPinned = false
    }

    /// Clear any host override.
    func clearOverride() {
        isPinned = false
        isBuried = false
    }
}
