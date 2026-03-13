import Foundation
import SwiftData

@Model
final class Track {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var albumTitle: String?
    var artworkURL: String?
    var appleMusicID: String?
    var spotifyID: String?
    var durationSeconds: Double
    var addedBy: UUID
    var addedAt: Date

    var bridge: Bridge?

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
}
