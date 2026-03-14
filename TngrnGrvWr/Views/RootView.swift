import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var users: [User]
    @State private var onboardingComplete = false

    var body: some View {
        if users.isEmpty && !onboardingComplete {
            OnboardingView {
                onboardingComplete = true
            }
        } else {
            MainTabView()
        }
    }
}
