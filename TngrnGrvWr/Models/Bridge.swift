import Foundation
import SwiftData

@Model
final class Bridge {
    @Attribute(.unique) var id: UUID
    var name: String
    var hostID: UUID
    var isCollaborative: Bool
    var isPublic: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade) var tracks: [Track]
    @Relationship(deleteRule: .cascade) var messages: [Message]

    init(
        id: UUID = UUID(),
        name: String,
        hostID: UUID,
        isCollaborative: Bool = true,
        isPublic: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.hostID = hostID
        self.isCollaborative = isCollaborative
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.tracks = []
        self.messages = []
    }
}
