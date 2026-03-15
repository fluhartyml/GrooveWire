import Foundation
import SwiftData

enum AgeCategory: String, Codable {
    case child   // under 13
    case teen    // 13-17
    case adult   // 18+
    case unknown // no birthday set
}

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

    // COPPA fields
    var birthday: Date?
    var privacyLevel: String = "private"
    var hasCompletedAgeGate: Bool = false
    var parentalConsentAcknowledged: Bool = false

    init(
        id: UUID = UUID(),
        displayName: String,
        email: String? = nil,
        phoneNumber: String? = nil,
        streamingService: StreamingService = .none,
        avatarURL: String? = nil,
        birthday: Date? = nil,
        hasCompletedAgeGate: Bool = false,
        parentalConsentAcknowledged: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.phoneNumber = phoneNumber
        self.streamingService = streamingService
        self.avatarURL = avatarURL
        self.isProfileComplete = !displayName.isEmpty
        self.birthday = birthday
        self.hasCompletedAgeGate = hasCompletedAgeGate
        self.parentalConsentAcknowledged = parentalConsentAcknowledged
        self.createdAt = createdAt

        if let birthday {
            self.privacyLevel = Self.computeAgeCategory(from: birthday) == .adult ? "public" : "private"
        }
    }

    // MARK: - Age Computed Properties

    var age: Int? {
        guard let birthday else { return nil }
        return Calendar.current.dateComponents([.year], from: birthday, to: Date()).year
    }

    var ageCategory: AgeCategory {
        guard let birthday else { return .unknown }
        return Self.computeAgeCategory(from: birthday)
    }

    var isUnderage: Bool {
        guard let age else { return false }
        return age < 18
    }

    var isChild: Bool {
        guard let age else { return false }
        return age < 13
    }

    var canChangePrivacy: Bool {
        ageCategory == .adult
    }

    var effectivePrivacy: String {
        switch ageCategory {
        case .child, .teen: return "private"
        case .adult, .unknown: return privacyLevel
        }
    }

    func bridgeDisplayName(isSelf: Bool) -> String {
        if isSelf { return displayName }
        switch ageCategory {
        case .child:
            return "Listener"
        case .teen:
            return parentalConsentAcknowledged ? displayName : "Listener"
        case .adult, .unknown:
            return displayName
        }
    }

    // MARK: - Helpers

    static func computeAgeCategory(from birthday: Date) -> AgeCategory {
        let years = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        if years < 13 { return .child }
        if years < 18 { return .teen }
        return .adult
    }
}
