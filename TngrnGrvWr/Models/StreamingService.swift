import Foundation

enum StreamingService: String, Codable, CaseIterable {
    case none = "none"
    case appleMusic = "apple_music"
    case spotify = "spotify"

    var displayName: String {
        switch self {
        case .none: "Not Connected"
        case .appleMusic: "Apple Music"
        case .spotify: "Spotify"
        }
    }

    var iconName: String {
        switch self {
        case .none: "speaker.slash"
        case .appleMusic: "apple.logo"
        case .spotify: "dot.radiowaves.left.and.right"
        }
    }
}
