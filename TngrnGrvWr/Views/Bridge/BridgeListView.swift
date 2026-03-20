import SwiftUI
import SwiftData

struct BridgeListView: View {
    @Binding var selectedBridgeID: UUID?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bridge.createdAt, order: .reverse) private var bridges: [Bridge]
    @Query(sort: \SavedPlaylist.createdAt, order: .reverse) private var playlists: [SavedPlaylist]
    @Query private var users: [User]
    @Environment(PlaybackManager.self) private var playbackManager
    @State private var showNewBridge = false
    @State private var newBridgeName = ""
    @State private var newBridgePrivate = false
    @State private var expandedPlaylists: Set<UUID> = []
    @State private var navigationPath = NavigationPath()
    @State private var renameBridge: Bridge?
    @State private var renameText = ""
    @State private var shareBridge: Bridge?

    private var currentUser: User? { users.first }
    private var isUnderage: Bool { currentUser?.isUnderage ?? false }

    var body: some View {
        NavigationStack(path: $navigationPath) {
        List {
            if bridges.isEmpty {
                Section("Active Bridges") {
                    Text("Tap + to create your first bridge.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(bridges) { bridge in
                    Section {
                        NavigationLink(value: bridge) {
                            BridgeCard(bridge: bridge)
                        }
                        .contextMenu {
                            Button {
                                navigationPath.append(bridge)
                            } label: {
                                Label("Open Bridge", systemImage: "arrow.right.circle")
                            }

                            Button {
                                shareBridge = bridge
                            } label: {
                                Label("Invite", systemImage: "paperplane")
                            }

                            Button {
                                renameBridge = bridge
                                renameText = bridge.name
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }

                            Button {
                                if bridge.isActive { bridge.stopBridge() }
                                else { bridge.startBridge() }
                            } label: {
                                Label(
                                    bridge.isActive ? "Stop Bridge" : "Start Bridge",
                                    systemImage: bridge.isActive ? "stop.circle" : "play.circle"
                                )
                            }

                            Divider()

                            Button(role: .destructive) {
                                modelContext.delete(bridge)
                                try? modelContext.save()
                            } label: {
                                Label("Delete Bridge", systemImage: "trash")
                            }
                        }
                    } header: {
                        if bridge == bridges.first {
                            Text("Active Bridges")
                        }
                    }

                    // Tracks in their own section so NavigationLink doesn't swallow taps
                    if !bridge.trackList.isEmpty {
                        Section {
                            ForEach(bridge.trackList.prefix(5)) { track in
                                trackPlayRow(track: track, bridge: bridge, queue: bridge.trackList)
                            }

                            if bridge.trackList.count > 5 {
                                NavigationLink(value: bridge) {
                                    Text("+ \(bridge.trackList.count - 5) more tracks")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }

            Section("Saved Playlists") {
                if playlists.isEmpty {
                    Text("Playlists you save from bridges will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(playlists) { playlist in
                        // Playlist header row with play button
                        HStack(spacing: 12) {
                            Button {
                                if expandedPlaylists.contains(playlist.id) {
                                    expandedPlaylists.remove(playlist.id)
                                } else {
                                    expandedPlaylists.insert(playlist.id)
                                }
                            } label: {
                                Image(systemName: expandedPlaylists.contains(playlist.id) ? "chevron.down" : "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)
                            }
                            .buttonStyle(.plain)

                            Image(systemName: "music.note.list")
                                .font(.title3)
                                .foregroundStyle(.orange)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(playlist.name)
                                    .font(.subheadline)
                                Text("\(playlist.trackCount) tracks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if playlist.spotifyPlaylistID != nil {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }

                            if !playlist.trackList.isEmpty {
                                Button {
                                    playbackManager.play(
                                        track: playlist.trackList[0],
                                        from: playlist.trackList
                                    )
                                } label: {
                                    Image(systemName: "play.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                                .buttonStyle(.plain)
                                .help("Play playlist")
                            }
                        }

                        // Expanded tracks
                        if expandedPlaylists.contains(playlist.id) {
                            if playlist.trackList.isEmpty {
                                Text("No tracks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 60)
                            } else {
                                ForEach(playlist.trackList) { track in
                                    trackPlayRow(track: track, queue: playlist.trackList)
                                        .padding(.leading, 48)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deletePlaylists)
                }
            }
        }
        .navigationDestination(for: Bridge.self) { bridge in
            BridgeView(bridge: bridge)
        }
        .onChange(of: selectedBridgeID) { _, newID in
            if let newID, let bridge = bridges.first(where: { $0.id == newID }) {
                navigationPath.append(bridge)
                selectedBridgeID = nil
            }
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
            if !isUnderage {
                Button("Create Public") {
                    newBridgePrivate = false
                    createBridge()
                }
                Button("Create Private") {
                    newBridgePrivate = true
                    createBridge()
                }
            } else {
                Button("Create") { createBridge() }
            }
            Button("Cancel", role: .cancel) {
                newBridgeName = ""
                newBridgePrivate = false
            }
        } message: {
            if isUnderage {
                Text("Give your bridge a name. Bridges are always private for users under 18.")
            } else {
                Text("Give your bridge a name. Public bridges can be joined by anyone with the link.")
            }
        }
        .sheet(item: $shareBridge) { bridge in
            BridgeShareSheet(bridge: bridge)
        }
        .alert("Rename Bridge", isPresented: Binding(
            get: { renameBridge != nil },
            set: { if !$0 { renameBridge = nil } }
        )) {
            TextField("Bridge name", text: $renameText)
            Button("Save") {
                let name = renameText.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { renameBridge?.name = name }
                renameBridge = nil
            }
            Button("Cancel", role: .cancel) { renameBridge = nil }
        }
        } // NavigationStack
    }

    private func createBridge() {
        let name = newBridgeName.trimmingCharacters(in: .whitespaces)
        let bridge = Bridge(
            name: name.isEmpty ? "My Bridge" : name,
            hostID: currentUser?.id ?? UUID(),
            isPublic: isUnderage ? false : !newBridgePrivate
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

    private func deletePlaylists(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(playlists[index])
        }
    }

    private func removeTrack(_ track: Track, from bridge: Bridge) {
        bridge.trackList.removeAll { $0.id == track.id }
        modelContext.delete(track)
    }

    // MARK: - Playable Track Row

    private func trackPlayRow(track: Track, bridge: Bridge? = nil, queue: [Track] = []) -> some View {
        HStack(spacing: 10) {
            if let urlString = track.artworkURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(.caption)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if bridge != nil {
                Button { track.pin() } label: {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Move to top")

                Button { track.bury() } label: {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Move to bottom")

                Button { removeTrack(track, from: bridge!) } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove track")
            }

            Button {
                playbackManager.play(track: track, from: queue.isEmpty ? nil : queue)
            } label: {
                Image(systemName: "play.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    BridgeListView(selectedBridgeID: .constant(nil))
}
