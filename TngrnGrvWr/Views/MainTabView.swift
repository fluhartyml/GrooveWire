import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = "home"

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house.fill", value: "home") {
                    NavigationStack {
                        HomeView()
                    }
                }

                Tab("GrooveWire", systemImage: "antenna.radiowaves.left.and.right", value: "groovewire") {
                    NavigationStack {
                        GrooveWireView()
                    }
                }

                Tab("My Library", systemImage: "rectangle.split.1x2", value: "library") {
                    NavigationStack {
                        LibraryListView()
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
