import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack {
                    HomeView()
                }
            }

            Tab("GrooveWire", systemImage: "antenna.radiowaves.left.and.right") {
                NavigationStack {
                    BridgeListView()
                }
            }

            Tab("Profile", systemImage: "person.fill") {
                NavigationStack {
                    ProfileView()
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}
