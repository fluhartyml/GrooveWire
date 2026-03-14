import Foundation
import SwiftData

@Model
final class SavedPlaylist {
    var id: UUID = UUID()
    var name: String = ""
    var spotifyPlaylistID: String?
    var appleMusicPlaylistID: String?
    var playlistDescription: String?
    var isPublic: Bool = false
    var createdAt: Date = Date()
    var imageURL: String?
    var ownerName: String?

    @Relationship(deleteRule: .cascade) var tracks: [Track]?

    init(
        id: UUID = UUID(),
        name: String,
        spotifyPlaylistID: String? = nil,
        appleMusicPlaylistID: String? = nil,
        playlistDescription: String? = nil,
        isPublic: Bool = false,
        createdAt: Date = Date(),
        imageURL: String? = nil,
        ownerName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.spotifyPlaylistID = spotifyPlaylistID
        self.appleMusicPlaylistID = appleMusicPlaylistID
        self.playlistDescription = playlistDescription
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.imageURL = imageURL
        self.ownerName = ownerName
        self.tracks = []
    }

    /// Safe accessor for tracks (unwraps optional relationship)
    var trackList: [Track] {
        get { tracks ?? [] }
        set { tracks = newValue }
    }

    var trackCount: Int { trackList.count }
}
