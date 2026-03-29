import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PlaylistListView: View {
    var onBridgeCreated: ((UUID) -> Void)?

    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Query(sort: \Bridge.createdAt, order: .reverse) private var bridges: [Bridge]
    @Query(sort: \SavedPlaylist.createdAt, order: .reverse) private var savedPlaylists: [SavedPlaylist]
    @State private var selectedPlaylist: SavedPlaylist?
    @State private var showBridgePicker = false
    @State private var showAddPlaylist = false
    @State private var transferTarget: SavedPlaylist?
    @State private var musicTransferTarget: SavedPlaylist?
    @State private var exportPlaylist: SavedPlaylist?
    @State private var searchTargetPlaylist: SavedPlaylist?
    @State private var isSyncing = false
    @State private var syncMessage: String?

    // All tracks for the selected playlist, or all playlists combined
    private var displayedTracks: [Track] {
        if let selected = selectedPlaylist {
            return selected.trackList
        }
        // "All Songs" — flatten every saved playlist
        return savedPlaylists.flatMap { $0.trackList }
    }

    private var trackSectionTitle: String {
        if let selected = selectedPlaylist {
            return "\(selected.name) (\(selected.trackCount) tracks)"
        }
        let total = savedPlaylists.reduce(0) { $0 + $1.trackCount }
        return "All Songs (\(total) tracks)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top: Playlists ──
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Playlists")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    Spacer()
                }

                List {
                    // "All Songs" row
                    playlistButton(name: "All Songs", icon: "music.note", count: nil, isSelected: selectedPlaylist == nil) {
                        selectedPlaylist = nil
                    }

                    ForEach(savedPlaylists) { playlist in
                        playlistButton(
                            name: playlist.name,
                            icon: playlist.isPublic ? "globe" : "lock.fill",
                            count: playlist.trackCount,
                            isSelected: selectedPlaylist?.id == playlist.id
                        ) {
                            selectedPlaylist = playlist
                        }
                        .contextMenu {
                            Button {
                                createBridgeFromPlaylist(playlist)
                            } label: {
                                Label("Create GrooveWire Bridge from Playlist", systemImage: "antenna.radiowaves.left.and.right")
                            }
                            .disabled(playlist.trackList.isEmpty)

                            Button {
                                searchTargetPlaylist = playlist
                            } label: {
                                Label("Add Tracks", systemImage: "plus.circle")
                            }

                            Button {
                                playlist.isPublic.toggle()
                                try? modelContext.save()
                            } label: {
                                Label(playlist.isPublic ? "Make Private" : "Make Public",
                                      systemImage: playlist.isPublic ? "lock.fill" : "globe")
                            }

                            #if os(macOS)
                            if playlist.trackList.contains(where: { $0.spotifyID != nil }) && appleMusicService.isConnected {
                                Button {
                                    musicTransferTarget = playlist
                                } label: {
                                    Label("Transfer Playlist", systemImage: "apple.logo")
                                }
                            }
                            #endif

                            Button {
                                transferTarget = playlist
                            } label: {
                                Label("Transfer to Other Service", systemImage: "arrow.triangle.2.circlepath")
                            }

                            Divider()

                            Button(role: .destructive) {
                                deletePlaylist(playlist)
                            } label: {
                                Label("Remove from Library", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .frame(maxHeight: .infinity)
            .background(.ultraThinMaterial)

            Divider()

            // ── Bottom: Tracks ──
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(trackSectionTitle)
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    Spacer()
                    if !displayedTracks.isEmpty {
                        Button {
                            showBridgePicker = true
                        } label: {
                            Label("Load into GrooveWire Bridge", systemImage: "antenna.radiowaves.left.and.right")
                                .font(.caption)
                        }
                        .padding(.trailing)
                        .padding(.top, 8)
                    }
                }

                if displayedTracks.isEmpty {
                    VStack {
                        Spacer()
                        Text("Select a playlist above")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                        Spacer()
                    }
                } else {
                    List(displayedTracks) { track in
                        TrackRow(track: track)
                            .contextMenu {
                                if let playlist = selectedPlaylist {
                                    Button(role: .destructive) {
                                        removeTrack(track, from: playlist)
                                    } label: {
                                        Label("Remove from Playlist", systemImage: "trash")
                                    }
                                }
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .navigationTitle("My Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    if spotifyService.isConnected {
                        Button {
                            Task { await syncFromSpotify() }
                        } label: {
                            if isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                        }
                        .disabled(isSyncing)
                        .help("Sync from Spotify")
                    }

                    Button {
                        showAddPlaylist = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .alert("Spotify Sync", isPresented: Binding(
            get: { syncMessage != nil },
            set: { if !$0 { syncMessage = nil } }
        )) {
            Button("OK") { syncMessage = nil }
        } message: {
            Text(syncMessage ?? "")
        }
        .sheet(isPresented: $showAddPlaylist) {
            AddPlaylistSheet(spotifyService: spotifyService) {}
        }
        .sheet(item: $searchTargetPlaylist) { playlist in
            AddTracksToPlaylistSheet(playlist: playlist, spotifyService: spotifyService)
        }
        .sheet(item: $transferTarget) { playlist in
            PlaylistTransferSheet(playlist: playlist)
        }
        .sheet(item: $musicTransferTarget) { playlist in
            PlaylistTransferToMusicSheet(playlist: playlist)
        }
        .sheet(item: $exportPlaylist) { playlist in
            M3UExportSheet(playlist: playlist)
        }
        .sheet(isPresented: $showBridgePicker) {
            BridgePickerSheet(tracks: displayedTracks, bridges: bridges) { bridge in
                for track in displayedTracks {
                    bridge.trackList.append(track)
                }
                try? modelContext.save()
            }
        }
    }

    // MARK: - Playlist Row Button

    @ViewBuilder
    private func playlistButton(name: String, icon: String, count: Int?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? themeColor : .secondary)

                Text(name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()

                if let count {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isSelected ? themeColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func removeTrack(_ track: Track, from playlist: SavedPlaylist) {
        playlist.trackList.removeAll { $0.id == track.id }
        modelContext.delete(track)
        try? modelContext.save()
        print("[Library] Removed '\(track.title)' from playlist '\(playlist.name)'")
    }

    private func createBridgeFromPlaylist(_ playlist: SavedPlaylist) {
        let bridge = Bridge(
            name: playlist.name,
            hostID: UUID(),
            isPublic: false
        )
        modelContext.insert(bridge)

        for track in playlist.trackList {
            let bridgeTrack = Track(
                title: track.title,
                artist: track.artist,
                albumTitle: track.albumTitle,
                artworkURL: track.artworkURL,
                appleMusicID: track.appleMusicID,
                spotifyID: track.spotifyID,
                durationSeconds: track.durationSeconds,
                addedBy: UUID()
            )
            modelContext.insert(bridgeTrack)
            bridge.trackList.append(bridgeTrack)
        }

        try? modelContext.save()
        print("[Library] Created bridge '\(playlist.name)' with \(playlist.trackCount) tracks")
        onBridgeCreated?(bridge.id)
    }

    private func deletePlaylist(_ playlist: SavedPlaylist) {
        // Also unfollow on Spotify if we have an ID
        if let spotifyID = playlist.spotifyPlaylistID {
            Task {
                try? await spotifyService.unfollowPlaylist(playlistID: spotifyID)
            }
        }

        if selectedPlaylist?.id == playlist.id {
            selectedPlaylist = nil
        }
        modelContext.delete(playlist)
        try? modelContext.save()
        print("[Library] Deleted playlist '\(playlist.name)' from local library")
    }

    private func syncFromSpotify() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let remotePlaylists = try await spotifyService.fetchPlaylists()
            let existingIDs = Set(savedPlaylists.compactMap { $0.spotifyPlaylistID })

            var added = 0
            var skipped = 0
            for remote in remotePlaylists {
                guard !existingIDs.contains(remote.id) else { continue }

                // Fetch tracks — skip this playlist if we get a 403
                let tracks: [Track]
                do {
                    tracks = try await spotifyService.fetchPlaylistTracks(playlistID: remote.id)
                } catch SpotifyError.forbidden {
                    print("[Library] Skipping '\(remote.name)' — 403 forbidden")
                    skipped += 1
                    continue
                }

                let saved = SavedPlaylist(
                    name: remote.name,
                    spotifyPlaylistID: remote.id,
                    playlistDescription: remote.description,
                    isPublic: false,
                    imageURL: remote.imageURL,
                    ownerName: remote.ownerName
                )
                modelContext.insert(saved)

                for track in tracks {
                    let localTrack = Track(
                        title: track.title,
                        artist: track.artist,
                        albumTitle: track.albumTitle,
                        artworkURL: track.artworkURL,
                        spotifyID: track.spotifyID,
                        durationSeconds: track.durationSeconds,
                        addedBy: UUID()
                    )
                    localTrack.savedPlaylist = saved
                    modelContext.insert(localTrack)
                    saved.trackList.append(localTrack)
                }

                added += 1
                print("[Library] Synced '\(remote.name)' (\(tracks.count) tracks)")
            }

            try modelContext.save()

            var message = ""
            if added > 0 {
                message = "Added \(added) new playlist\(added == 1 ? "" : "s") from Spotify."
            } else {
                message = "All Spotify playlists are already in your library."
            }
            if skipped > 0 {
                message += " \(skipped) skipped (access denied)."
            }
            syncMessage = message
        } catch {
            syncMessage = "Sync failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Add Playlist Sheet

enum AddPlaylistMode: String, CaseIterable {
    case create = "New"
    case link = "Paste Link"
    case songs = "Import Songs"
    case file = "Import File"
    case appleMusic = "Apple Music"
}

struct AddPlaylistSheet: View {
    let spotifyService: SpotifyService
    let onAdded: () -> Void
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @State private var mode: AddPlaylistMode = .create

    // Create mode
    @State private var newPlaylistName = ""

    // Link mode
    @State private var linkText = ""

    // Songs mode (manual text entry)
    @State private var songsPlaylistName = ""
    @State private var songsText = ""

    // File mode
    @State private var filePlaylistName = ""
    @State private var fileContents = ""
    @State private var showFilePicker = false

    // Apple Music mode
    @State private var appleMusicPlaylists: [AppleMusicPlaylist] = []
    @State private var selectedAppleMusicPlaylist: AppleMusicPlaylist?
    @State private var isLoadingAppleMusicPlaylists = false

    @State private var isLoading = false
    @State private var statusMessage = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $mode) {
                    ForEach(AddPlaylistMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                switch mode {
                case .create:
                    Section {
                        TextField("Playlist name", text: $newPlaylistName)
                            .textFieldStyle(.roundedBorder)
                    } header: {
                        Text("New Playlist")
                    } footer: {
                        Text("Create an empty playlist. Add tracks later from Search or other playlists.")
                    }

                case .link:
                    Section {
                        TextField("Spotify playlist link or URI", text: $linkText)
                            .textFieldStyle(.roundedBorder)
                    } header: {
                        Text("Paste a Spotify Link")
                    } footer: {
                        Text("Paste a link like open.spotify.com/playlist/... or a spotify:playlist: URI from a friend.")
                    }

                case .songs:
                    Section {
                        TextField("Playlist name", text: $songsPlaylistName)
                            .textFieldStyle(.roundedBorder)
                    } header: {
                        Text("Playlist Name")
                    }

                    Section {
                        TextEditor(text: $songsText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 150)
                    } header: {
                        Text("Songs")
                    } footer: {
                        Text("One song per line: Title, Artist\nOr with album: Title, Artist, Album\nA header row is automatically skipped.")
                    }

                case .file:
                    Section {
                        HStack {
                            TextField("Playlist name", text: $filePlaylistName)
                                .textFieldStyle(.roundedBorder)
                            Button("Browse...") {
                                showFilePicker = true
                            }
                        }
                    } header: {
                        Text("Playlist Name")
                    } footer: {
                        Text("Auto-filled from the filename.")
                    }

                    if !fileContents.isEmpty {
                        Section {
                            let lines = parsedSongCount(from: fileContents)
                            Label("\(lines) songs detected", systemImage: "music.note.list")
                                .font(.subheadline)
                        }
                    }

                case .appleMusic:
                    if !appleMusicService.isConnected {
                        Section {
                            Label("Apple Music is not connected", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(themeColor)
                        }
                    } else if isLoadingAppleMusicPlaylists {
                        Section {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading playlists...")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if appleMusicPlaylists.isEmpty {
                        Section {
                            Text("No playlists found in your Apple Music library.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section("Select a Playlist") {
                            ForEach(appleMusicPlaylists) { playlist in
                                Button {
                                    selectedAppleMusicPlaylist = playlist
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(playlist.name)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                            Text("\(playlist.trackCount) tracks")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if selectedAppleMusicPlaylist?.id == playlist.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(themeColor)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if !statusMessage.isEmpty {
                    Section {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                        Button("Close") { dismiss() }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button(mode == .create ? "Create" : mode == .link ? "Save" : "Import") {
                            Task { await save() }
                        }
                        .disabled(isSaveDisabled)
                    }
                }
            }
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .appleMusic && appleMusicPlaylists.isEmpty && appleMusicService.isConnected {
                isLoadingAppleMusicPlaylists = true
                Task {
                    do {
                        appleMusicPlaylists = try await appleMusicService.fetchPlaylists()
                    } catch {
                        errorMessage = "Failed to load Apple Music playlists: \(error.localizedDescription)"
                    }
                    isLoadingAppleMusicPlaylists = false
                }
            }
        }
        .frame(minWidth: 450, minHeight: 350)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText, .plainText, .m3uPlaylist]) { result in
            switch result {
            case .success(let url):
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                if let contents = try? String(contentsOf: url, encoding: .utf8) {
                    fileContents = contents
                }
                let filename = url.deletingPathExtension().lastPathComponent
                if filePlaylistName.isEmpty {
                    filePlaylistName = filename
                }
            case .failure(let error):
                errorMessage = "Couldn't open file: \(error.localizedDescription)"
            }
        }
    }

    private var isSaveDisabled: Bool {
        switch mode {
        case .create:
            return newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .link:
            return linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
        case .songs:
            return songsPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || songsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || isLoading
        case .file:
            return filePlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || fileContents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || isLoading
        case .appleMusic:
            return selectedAppleMusicPlaylist == nil || isLoading
        }
    }

    private func save() async {
        switch mode {
        case .create:
            createEmptyPlaylist()
        case .link:
            await saveFromLink()
        case .songs:
            await createFromSongs(name: songsPlaylistName, rawText: songsText)
        case .file:
            await createFromSongs(name: filePlaylistName, rawText: fileContents)
        case .appleMusic:
            await importFromAppleMusic()
        }
    }

    private func createEmptyPlaylist() {
        let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        let playlist = SavedPlaylist(
            name: name,
            isPublic: false
        )
        modelContext.insert(playlist)
        try? modelContext.save()
        print("[Library] Created empty playlist '\(name)'")
        onAdded()
        dismiss()
    }

    private func importFromAppleMusic() async {
        guard let selected = selectedAppleMusicPlaylist else { return }

        isLoading = true
        errorMessage = nil
        statusMessage = "Fetching tracks from \(selected.name)..."

        do {
            let tracks = try await appleMusicService.fetchPlaylistTracks(playlistID: selected.id)

            guard !tracks.isEmpty else {
                errorMessage = "No tracks found in this playlist."
                isLoading = false
                return
            }

            let savedPlaylist = SavedPlaylist(
                name: selected.name,
                appleMusicPlaylistID: selected.id,
                playlistDescription: selected.description,
                isPublic: false
            )
            modelContext.insert(savedPlaylist)

            for track in tracks {
                let localTrack = Track(
                    title: track.title,
                    artist: track.artist,
                    albumTitle: track.albumTitle,
                    artworkURL: track.artworkURL,
                    appleMusicID: track.appleMusicID,
                    durationSeconds: track.durationSeconds,
                    addedBy: UUID()
                )
                localTrack.savedPlaylist = savedPlaylist
                modelContext.insert(localTrack)
                savedPlaylist.trackList.append(localTrack)
            }

            try modelContext.save()
            print("[Library] Imported Apple Music playlist '\(selected.name)' with \(tracks.count) tracks")

            onAdded()
            dismiss()
        } catch {
            errorMessage = "Failed to import: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func saveFromLink() async {
        let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let playlistID = SpotifyService.playlistID(from: trimmed) else {
            errorMessage = "Couldn't find a playlist ID in that link. Make sure it's a Spotify playlist URL."
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            try await spotifyService.followPlaylist(playlistID: playlistID)

            // Save locally — we don't have track data for linked playlists yet,
            // but we save the shell so it appears in the library
            let savedPlaylist = SavedPlaylist(
                name: "Spotify Playlist",
                spotifyPlaylistID: playlistID,
                isPublic: true
            )
            modelContext.insert(savedPlaylist)
            try modelContext.save()
            print("[Library] Saved linked playlist locally")

            onAdded()
            dismiss()
        } catch {
            errorMessage = "Failed to save playlist: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func createFromSongs(name: String, rawText: String) async {
        let songEntries = parseSongEntries(from: rawText)

        guard !songEntries.isEmpty else {
            errorMessage = "No songs found. Enter one song per line: Title, Artist"
            return
        }

        isLoading = true
        errorMessage = nil
        var foundTracks: [Track] = []
        var notFound: [String] = []

        for (index, entry) in songEntries.enumerated() {
            statusMessage = "Searching \(index + 1)/\(songEntries.count): \(entry.title)..."

            do {
                let results = try await spotifyService.search(query: "\(entry.title) \(entry.artist)")
                if let match = results.first {
                    foundTracks.append(match)
                } else {
                    notFound.append("\(entry.title) — \(entry.artist)")
                }
            } catch {
                notFound.append("\(entry.title) — \(entry.artist)")
            }
        }

        if foundTracks.isEmpty {
            errorMessage = "Couldn't find any of those songs on Spotify."
            isLoading = false
            return
        }

        let trackIDs = foundTracks.compactMap { $0.spotifyID }

        statusMessage = "Creating playlist with \(trackIDs.count) tracks..."

        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let desc = "Created by GrooveWire"
            let spotifyPlaylistID = try await spotifyService.createPlaylist(name: trimmedName, description: desc, trackIDs: trackIDs)

            // Save locally in SwiftData
            let savedPlaylist = SavedPlaylist(
                name: trimmedName,
                spotifyPlaylistID: spotifyPlaylistID,
                playlistDescription: desc,
                isPublic: false
            )
            modelContext.insert(savedPlaylist)

            for track in foundTracks {
                let localTrack = Track(
                    title: track.title,
                    artist: track.artist,
                    albumTitle: track.albumTitle,
                    artworkURL: track.artworkURL,
                    spotifyID: track.spotifyID,
                    durationSeconds: track.durationSeconds,
                    addedBy: UUID()
                )
                localTrack.savedPlaylist = savedPlaylist
                modelContext.insert(localTrack)
                savedPlaylist.trackList.append(localTrack)
            }

            try modelContext.save()
            print("[Library] Saved playlist '\(trimmedName)' locally with \(foundTracks.count) tracks")

            if !notFound.isEmpty {
                statusMessage = "Created! \(notFound.count) song(s) not found: \(notFound.joined(separator: ", "))"
            }

            onAdded()
            dismiss()
        } catch {
            errorMessage = "Failed to create playlist: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Parsing

    private struct SongEntry {
        let title: String
        let artist: String
    }

    private func parseSongEntries(from text: String) -> [SongEntry] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Detect M3U format
        if lines.contains(where: { $0.hasPrefix("#EXTINF:") }) {
            return parseM3U(lines)
        }

        // CSV format
        return parseCSV(lines)
    }

    private func parseCSV(_ lines: [String]) -> [SongEntry] {
        var mutable = lines

        // Skip header row
        if let first = mutable.first?.lowercased(),
           first.contains("name") || first.contains("title") || first.contains("artist") {
            mutable.removeFirst()
        }

        return mutable.compactMap { line in
            let parts = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count >= 2 else { return nil }
            return SongEntry(title: parts[0], artist: parts[1])
        }
    }

    private func parseM3U(_ lines: [String]) -> [SongEntry] {
        // #EXTINF lines look like: #EXTINF:123,Artist - Title
        return lines.compactMap { line in
            guard line.hasPrefix("#EXTINF:") else { return nil }
            // Strip the #EXTINF:duration, prefix
            guard let commaIndex = line.firstIndex(of: ",") else { return nil }
            let displayText = String(line[line.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)

            // Try "Artist - Title" format
            if let dashRange = displayText.range(of: " - ") {
                let artist = String(displayText[displayText.startIndex..<dashRange.lowerBound])
                let title = String(displayText[dashRange.upperBound...])
                return SongEntry(title: title, artist: artist)
            }
            return nil
        }
    }

    private func parsedSongCount(from text: String) -> Int {
        parseSongEntries(from: text).count
    }
}

// MARK: - M3U UTType

extension UTType {
    static let m3uPlaylist = UTType(filenameExtension: "m3u") ?? .plainText
}

// MARK: - M3U Export Sheet

struct M3UExportSheet: View {
    let playlist: SavedPlaylist
    @Environment(TrackMatchingService.self) private var trackMatchingService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor

    @State private var isMatching = false
    @State private var matchedCount = 0
    @State private var m3uURL: URL?
    @State private var copiedLink = false

    private var needsMatching: Bool {
        appleMusicService.isConnected &&
        playlist.trackList.contains(where: { $0.spotifyID != nil && $0.appleMusicID == nil })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundStyle(themeColor)

                Text(playlist.name)
                    .font(.headline)

                Text("\(playlist.trackCount) tracks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if isMatching {
                    VStack(spacing: 8) {
                        ProgressView(value: trackMatchingService.matchProgress)
                            .tint(themeColor)
                        Text("Matching tracks to Apple Music...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                } else if matchedCount > 0 {
                    Label("\(matchedCount) tracks matched to Apple Music", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Divider()

                if let m3uURL {
                    #if os(macOS)
                    Button {
                        let musicAppURL = URL(fileURLWithPath: "/System/Applications/Music.app")
                        NSWorkspace.shared.open([m3uURL], withApplicationAt: musicAppURL, configuration: NSWorkspace.OpenConfiguration())
                        dismiss()
                    } label: {
                        Label("Open in Music", systemImage: "music.note")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeColor)
                    #endif

                    ShareLink(
                        item: m3uURL,
                        preview: SharePreview(playlist.name, image: Image(systemName: "music.note.list"))
                    ) {
                        Label("Share via AirDrop / Messages", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                if let spotifyID = playlist.spotifyPlaylistID {
                    Button {
                        let link = "https://open.spotify.com/playlist/\(spotifyID)"
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(link, forType: .string)
                        #else
                        UIPasteboard.general.string = link
                        #endif
                        copiedLink = true
                    } label: {
                        Label(copiedLink ? "Copied!" : "Copy Spotify Link",
                              systemImage: copiedLink ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(copiedLink ? .green : nil)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Export Playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 300)
        .task {
            if needsMatching {
                await matchTracks()
            }
            m3uURL = generateM3U()
        }
    }

    private func matchTracks() async {
        let tracksToMatch = playlist.trackList.filter { $0.spotifyID != nil && $0.appleMusicID == nil }
        guard !tracksToMatch.isEmpty else { return }

        isMatching = true
        let results = await trackMatchingService.matchPlaylist(tracksToMatch, to: .appleMusic)

        var matched = 0
        for result in results {
            if let matchedTrack = result.matchedTrack, let appleID = matchedTrack.appleMusicID {
                result.originalTrack.appleMusicID = appleID
                result.originalTrack.matchConfidence = result.confidence
                matched += 1
            }
        }

        if matched > 0 {
            try? modelContext.save()
        }

        matchedCount = matched
        isMatching = false
    }

    private func generateM3U() -> URL {
        var m3u = "#EXTM3U\n"
        for track in playlist.trackList {
            let duration = Int(track.durationSeconds)
            m3u += "#EXTINF:\(duration),\(track.artist) - \(track.title)\n"
            if let appleMusicID = track.appleMusicID {
                m3u += "https://music.apple.com/song/\(appleMusicID)\n"
            } else if let spotifyID = track.spotifyID {
                m3u += "https://open.spotify.com/track/\(spotifyID)\n"
            } else {
                m3u += "\(track.artist) - \(track.title).mp3\n"
            }
        }
        let filename = playlist.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).m3u")
        try? m3u.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

// MARK: - Add Tracks to Playlist Sheet

struct AddTracksToPlaylistSheet: View {
    let playlist: SavedPlaylist
    let spotifyService: SpotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @State private var searchQuery = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching = false
    @State private var addedCount = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    TextField("Search songs...", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            Task { await search() }
                        }
                    Button {
                        Task { await search() }
                    } label: {
                        if isSearching {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                    }
                    .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                }
                .padding()

                if addedCount > 0 {
                    Text("\(addedCount) track\(addedCount == 1 ? "" : "s") added to \(playlist.name)")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal)
                }

                if searchResults.isEmpty {
                    Spacer()
                    Text("Search for songs to add to \"\(playlist.name)\"")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List(searchResults) { track in
                        HStack(spacing: 10) {
                            if let urlString = track.artworkURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 4).fill(.quaternary)
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if track.spotifyID != nil {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                            if track.appleMusicID != nil {
                                Image(systemName: "apple.logo")
                                    .font(.caption2)
                                    .foregroundStyle(.pink)
                            }

                            Button {
                                addTrack(track)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(themeColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Tracks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 350)
    }

    private func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true

        var results: [Track] = []

        // Search Spotify
        if spotifyService.isConnected {
            do {
                let spotifyResults = try await spotifyService.search(query: query)
                results.append(contentsOf: spotifyResults)
            } catch {
                print("[AddTracks] Spotify search failed: \(error.localizedDescription)")
            }
        }

        // Search Apple Music
        if appleMusicService.isConnected {
            do {
                let appleResults = try await appleMusicService.search(query: query)
                // Only add Apple Music results that aren't already in Spotify results (by title+artist)
                let existingKeys = Set(results.map { "\($0.title.lowercased())|\($0.artist.lowercased())" })
                for track in appleResults {
                    let key = "\(track.title.lowercased())|\(track.artist.lowercased())"
                    if !existingKeys.contains(key) {
                        results.append(track)
                    }
                }
            } catch {
                print("[AddTracks] Apple Music search failed: \(error.localizedDescription)")
            }
        }

        searchResults = results
        isSearching = false
    }

    private func addTrack(_ track: Track) {
        let newTrack = Track(
            title: track.title,
            artist: track.artist,
            albumTitle: track.albumTitle,
            artworkURL: track.artworkURL,
            appleMusicID: track.appleMusicID,
            spotifyID: track.spotifyID,
            durationSeconds: track.durationSeconds,
            addedBy: UUID()
        )
        newTrack.savedPlaylist = playlist
        modelContext.insert(newTrack)
        playlist.trackList.append(newTrack)
        try? modelContext.save()
        addedCount += 1
        print("[Library] Added '\(track.title)' to playlist '\(playlist.name)'")
    }
}
