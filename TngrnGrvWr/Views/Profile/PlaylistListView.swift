import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PlaylistListView: View {
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bridge.createdAt, order: .reverse) private var bridges: [Bridge]
    @Query(sort: \SavedPlaylist.createdAt, order: .reverse) private var savedPlaylists: [SavedPlaylist]
    @State private var selectedPlaylist: SavedPlaylist?
    @State private var showBridgePicker = false
    @State private var showAddPlaylist = false

    // All tracks for the selected playlist, or all playlists combined
    private var displayedTracks: [Track] {
        if let selected = selectedPlaylist {
            return selected.tracks
        }
        // "All Songs" — flatten every saved playlist
        return savedPlaylists.flatMap { $0.tracks }
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
                            if let spotifyID = playlist.spotifyPlaylistID {
                                ShareLink(
                                    item: URL(string: "https://open.spotify.com/playlist/\(spotifyID)")!,
                                    preview: SharePreview(playlist.name, image: Image(systemName: "music.note.list"))
                                ) {
                                    Label("Share Spotify Link", systemImage: "square.and.arrow.up")
                                }

                                Divider()
                            }

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
                            Label("Load into Bridge", systemImage: "antenna.radiowaves.left.and.right")
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
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .navigationTitle("My Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddPlaylist = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddPlaylist) {
            AddPlaylistSheet(spotifyService: spotifyService) {}
        }
        .sheet(isPresented: $showBridgePicker) {
            BridgePickerSheet(tracks: displayedTracks, bridges: bridges) { bridge in
                for track in displayedTracks {
                    bridge.tracks.append(track)
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
                    .foregroundStyle(isSelected ? .orange : .secondary)

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
            .background(isSelected ? Color.orange.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

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
}

// MARK: - Add Playlist Sheet

enum AddPlaylistMode: String, CaseIterable {
    case link = "Paste Link"
    case songs = "Import Songs"
    case file = "Import File"
}

struct AddPlaylistSheet: View {
    let spotifyService: SpotifyService
    let onAdded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var mode: AddPlaylistMode = .link

    // Link mode
    @State private var linkText = ""

    // Songs mode (manual text entry)
    @State private var songsPlaylistName = ""
    @State private var songsText = ""

    // File mode
    @State private var filePlaylistName = ""
    @State private var fileContents = ""
    @State private var showFilePicker = false

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
                        Button(mode == .link ? "Save" : "Import") {
                            Task { await save() }
                        }
                        .disabled(isSaveDisabled)
                    }
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
        }
    }

    private func save() async {
        switch mode {
        case .link:
            await saveFromLink()
        case .songs:
            await createFromSongs(name: songsPlaylistName, rawText: songsText)
        case .file:
            await createFromSongs(name: filePlaylistName, rawText: fileContents)
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
                savedPlaylist.tracks.append(localTrack)
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
