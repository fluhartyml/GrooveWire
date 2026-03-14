import SwiftUI
import SwiftData

struct BridgeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bridge.createdAt, order: .reverse) private var bridges: [Bridge]
    @State private var showNewBridge = false
    @State private var newBridgeName = ""
    @State private var newBridgePrivate = false

    var body: some View {
        List {
            ForEach(bridges) { bridge in
                NavigationLink(destination: BridgeView(bridge: bridge)) {
                    BridgeCard(bridge: bridge)
                }
            }
            .onDelete(perform: deleteBridges)
        }
        .navigationTitle("GrooveWire")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNewBridge = true } label: {
                    Label("New Bridge", systemImage: "plus")
                }
            }
        }
        .alert("New Bridge", isPresented: $showNewBridge) {
            TextField("Bridge name", text: $newBridgeName)
            Toggle("Private (host-only invites)", isOn: $newBridgePrivate)
            Button("Create") { createBridge() }
            Button("Cancel", role: .cancel) {
                newBridgeName = ""
                newBridgePrivate = false
            }
        } message: {
            Text("Give your bridge a name.")
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
        let name = newBridgeName.trimmingCharacters(in: .whitespaces)
        let bridge = Bridge(
            name: name.isEmpty ? "My Bridge" : name,
            hostID: UUID(),
            isPublic: !newBridgePrivate
        )
        modelContext.insert(bridge)
        newBridgeName = ""
        newBridgePrivate = false
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
