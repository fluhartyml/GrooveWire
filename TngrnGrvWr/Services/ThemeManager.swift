import SwiftUI

@Observable
final class ThemeManager {
    var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "appTheme")
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.tangerine.rawValue
        self.currentTheme = AppTheme(rawValue: saved) ?? .tangerine
    }

    var accentColor: Color { currentTheme.accentColor }
}

// MARK: - Environment convenience

private struct ThemeColorKey: EnvironmentKey {
    static let defaultValue: Color = .orange
}

extension EnvironmentValues {
    var themeColor: Color {
        get { self[ThemeColorKey.self] }
        set { self[ThemeColorKey.self] = newValue }
    }
}
