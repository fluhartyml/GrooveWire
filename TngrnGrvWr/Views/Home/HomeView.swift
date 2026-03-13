import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Bridge.createdAt, order: .reverse) private var bridges: [Bridge]

    var body: some View {
        List {
            Section("Active Bridges") {
                if bridges.isEmpty {
                    ContentUnavailableView(
                        "No Bridges Yet",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("Create or join a bridge to start listening together.")
                    )
                } else {
                    ForEach(bridges) { bridge in
                        NavigationLink(destination: BridgeView(bridge: bridge)) {
                            BridgeCard(bridge: bridge)
                        }
                    }
                }
            }
        }
        .navigationTitle("Home")
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
