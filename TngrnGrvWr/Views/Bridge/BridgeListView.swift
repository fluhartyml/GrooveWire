import SwiftUI
import SwiftData

struct BridgeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bridge.createdAt, order: .reverse) private var bridges: [Bridge]

    var body: some View {
        List {
            ForEach(bridges) { bridge in
                NavigationLink(destination: BridgeView(bridge: bridge)) {
                    BridgeCard(bridge: bridge)
                }
            }
            .onDelete(perform: deleteBridges)
        }
        .navigationTitle("Bridges")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: createBridge) {
                    Label("New Bridge", systemImage: "plus")
                }
            }
        }
        .overlay {
            if bridges.isEmpty {
                ContentUnavailableView(
                    "No Bridges",
                    systemImage: "antenna.radiowaves.left.and.right",
                    description: Text("Tap + to create your first bridge.")
                )
            }
        }
    }

    private func createBridge() {
        let bridge = Bridge(name: "New Bridge", hostID: UUID())
        modelContext.insert(bridge)
    }

    private func deleteBridges(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(bridges[index])
        }
    }
}

#Preview {
    NavigationStack {
        BridgeListView()
    }
}
