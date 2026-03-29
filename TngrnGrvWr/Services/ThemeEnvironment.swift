import SwiftUI

// MARK: - Theme Color Environment Key
// Hardcoded to Tangerine for v1.0. Theme picker deferred to future update.

private struct ThemeColorKey: EnvironmentKey {
    static let defaultValue: Color = Color(red: 1.0, green: 0.52, blue: 0.0)
}

extension EnvironmentValues {
    var themeColor: Color {
        get { self[ThemeColorKey.self] }
        set { self[ThemeColorKey.self] = newValue }
    }
}
