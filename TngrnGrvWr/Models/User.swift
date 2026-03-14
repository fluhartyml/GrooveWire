import Foundation
import SwiftData

@Model
final class User {
    var id: UUID = UUID()
    var displayName: String = ""
    var email: String?
    var phoneNumber: String?
    var streamingService: StreamingService = StreamingService.none
    var avatarURL: String?
    var isProfileComplete: Bool = false
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        displayName: String,
        email: String? = nil,
        phoneNumber: String? = nil,
        streamingService: StreamingService = .none,
        avatarURL: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.phoneNumber = phoneNumber
        self.streamingService = streamingService
        self.avatarURL = avatarURL
        self.isProfileComplete = !displayName.isEmpty
        self.createdAt = createdAt
    }
}
