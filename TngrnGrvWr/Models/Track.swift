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
    var sortOrder: Int = 0

    // Cross-service matching
    var matchConfidenceRaw: String?      // MatchConfidence raw value

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
        addedBy: UUID = UUID(),
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

    // MARK: - Cross-Service

    /// Computed match confidence from stored raw value.
    var matchConfidence: MatchConfidence? {
        get { matchConfidenceRaw.flatMap { MatchConfidence(rawValue: $0) } }
        set { matchConfidenceRaw = newValue?.rawValue }
    }

    /// True if this track is available on both Spotify and Apple Music.
    var isOnBothServices: Bool {
        spotifyID != nil && appleMusicID != nil
    }

    /// Which services this track is known to be available on.
    var availableServices: [StreamingService] {
        var services: [StreamingService] = []
        if spotifyID != nil { services.append(.spotify) }
        if appleMusicID != nil { services.append(.appleMusic) }
        return services
    }
}
