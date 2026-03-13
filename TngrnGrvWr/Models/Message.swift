import Foundation
import SwiftData

@Model
final class Message {
    @Attribute(.unique) var id: UUID
    var senderID: UUID
    var senderName: String
    var text: String
    var sentAt: Date

    var bridge: Bridge?

    init(
        id: UUID = UUID(),
        senderID: UUID,
        senderName: String,
        text: String,
        sentAt: Date = Date()
    ) {
        self.id = id
        self.senderID = senderID
        self.senderName = senderName
        self.text = text
        self.sentAt = sentAt
    }
}
