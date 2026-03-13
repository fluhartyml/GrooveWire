import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var streamingService: StreamingService
    var avatarURL: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        streamingService: StreamingService,
        avatarURL: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.streamingService = streamingService
        self.avatarURL = avatarURL
        self.createdAt = createdAt
    }
}
