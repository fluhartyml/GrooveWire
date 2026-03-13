import Foundation

enum StreamingService: String, Codable, CaseIterable {
    case appleMusic = "apple_music"
    case spotify = "spotify"

    var displayName: String {
        switch self {
        case .appleMusic: "Apple Music"
        case .spotify: "Spotify"
        }
    }

    var iconName: String {
        switch self {
        case .appleMusic: "apple.logo"
        case .spotify: "dot.radiowaves.left.and.right"
        }
    }
}
