import SwiftUI

struct ProfileView: View {
    var body: some View {
        List {
            Section("Account") {
                Label("Connect Apple Music", systemImage: "apple.logo")
                Label("Connect Spotify", systemImage: "dot.radiowaves.left.and.right")
            }

            Section("About") {
                Label("Tangerine Grovewire", systemImage: "antenna.radiowaves.left.and.right")
            }
        }
        .navigationTitle("Profile")
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
