import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case tangerine   // Default orange
    case midnight    // Deep blue
    case neon        // Electric green
    case lavender    // Purple
    case coral       // Warm pink-orange
    case slate       // Cool gray
    case crimson     // Deep red
    case ocean       // Teal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tangerine: "Tangerine"
        case .midnight: "Midnight"
        case .neon: "Neon"
        case .lavender: "Lavender"
        case .coral: "Coral"
        case .slate: "Slate"
        case .crimson: "Crimson"
        case .ocean: "Ocean"
        }
    }

    var accentColor: Color {
        switch self {
        case .tangerine: .orange
        case .midnight: Color(red: 0.2, green: 0.3, blue: 0.8)
        case .neon: Color(red: 0.0, green: 0.9, blue: 0.4)
        case .lavender: Color(red: 0.6, green: 0.4, blue: 0.9)
        case .coral: Color(red: 1.0, green: 0.4, blue: 0.3)
        case .slate: Color(red: 0.5, green: 0.55, blue: 0.6)
        case .crimson: Color(red: 0.8, green: 0.1, blue: 0.15)
        case .ocean: Color(red: 0.0, green: 0.7, blue: 0.7)
        }
    }

    var icon: String {
        switch self {
        case .tangerine: "sun.max.fill"
        case .midnight: "moon.stars.fill"
        case .neon: "bolt.fill"
        case .lavender: "sparkles"
        case .coral: "flame.fill"
        case .slate: "cloud.fill"
        case .crimson: "heart.fill"
        case .ocean: "water.waves"
        }
    }
}
