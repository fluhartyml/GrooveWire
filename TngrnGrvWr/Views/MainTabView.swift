import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = "home"
    @State private var selectedBridgeID: UUID?

    var body: some View {
        VStack(spacing: 0) {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: "home") {
                NavigationStack {
                    HomeView(
                        onBridgeTap: { bridgeID in
                            selectedBridgeID = bridgeID
                            selectedTab = "groovewire"
                        }
                    )
                }
            }

            Tab("GrooveWire", systemImage: "antenna.radiowaves.left.and.right", value: "groovewire") {
                BridgeListView(selectedBridgeID: $selectedBridgeID)
            }

            Tab("Profile", systemImage: "person.fill", value: "profile") {
                NavigationStack {
                    ProfileView()
                }
            }
        }

            MiniPlayerBar()
        }
    }
}

#Preview {
    MainTabView()
}
