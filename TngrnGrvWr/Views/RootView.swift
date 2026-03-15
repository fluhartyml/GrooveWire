import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var users: [User]
    @State private var onboardingComplete = false

    private var currentUser: User? { users.first }

    var body: some View {
        if users.isEmpty && !onboardingComplete {
            OnboardingView {
                onboardingComplete = true
            }
        } else if let user = currentUser, !user.hasCompletedAgeGate {
            AgeGateView(user: user)
        } else {
            MainTabView()
        }
    }
}
