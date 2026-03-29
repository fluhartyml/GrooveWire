import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum ImportMode: String, CaseIterable {
    case link = "Paste Link"
    case songs = "Import Songs"
    case file = "Import File"
    case appleMusic = "Apple Music"
}

/// Import playlist sheet for the GrooveWire tab.
/// Supports: Spotify URL, manual song entry, CSV/M3U file, Apple Music library.
struct ImportPlaylistSheet: View {
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @State private var mode: ImportMode = .link

    // Link mode
    @State private var linkText = ""

    // Songs mode
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
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $mode) {
                    ForEach(ImportMode.allCases, id: \.self) { m in
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
                        Text("Paste a link like open.spotify.com/playlist/... or a spotify:playlist: URI.")
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
                            Label("\(parsedSongCount(from: fileContents)) songs detected", systemImage: "music.note.list")
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

                if let success = successMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(success)
                                .foregroundStyle(.green)
                        }
                        .font(.callout)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Import Playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Import") {
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
                    durationSeconds: track.durationSeconds
                )
                localTrack.savedPlaylist = savedPlaylist
                modelContext.insert(localTrack)
                savedPlaylist.trackList.append(localTrack)
            }

            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to import: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func saveFromLink() async {
        let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let playlistID = SpotifyService.playlistID(from: trimmed) else {
            errorMessage = "Couldn't find a playlist ID in that link."
            return
        }

        guard spotifyService.isConnected else {
            errorMessage = "Connect Spotify in your Profile to import playlist links."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let playlistName = try await spotifyService.fetchPlaylistName(playlistID: playlistID)
            let tracks = try await spotifyService.fetchPlaylistTracks(playlistID: playlistID)

            let savedPlaylist = SavedPlaylist(
                name: playlistName,
                spotifyPlaylistID: playlistID,
                isPublic: false
            )
            modelContext.insert(savedPlaylist)

            for track in tracks {
                let localTrack = Track(
                    title: track.title,
                    artist: track.artist,
                    albumTitle: track.albumTitle,
                    artworkURL: track.artworkURL,
                    spotifyID: track.spotifyID,
                    durationSeconds: track.durationSeconds
                )
                localTrack.savedPlaylist = savedPlaylist
                modelContext.insert(localTrack)
                savedPlaylist.trackList.append(localTrack)
            }

            try modelContext.save()
            isLoading = false
            successMessage = "Imported \"\(playlistName)\" — \(tracks.count) tracks"
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch {
            errorMessage = "Failed to fetch playlist: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func createFromSongs(name: String, rawText: String) async {
        let songEntries = PlaylistParser.parseSongEntries(from: rawText)

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
                var results: [Track] = []
                let searchQuery = "\(entry.title) \(entry.artist)"

                if spotifyService.isConnected {
                    results = try await spotifyService.search(query: searchQuery)
                } else if appleMusicService.isConnected {
                    results = try await appleMusicService.search(query: searchQuery)
                }

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
            errorMessage = "Couldn't find any of those songs."
            isLoading = false
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Create on Spotify if connected
        var spotifyPlaylistID: String?
        if spotifyService.isConnected {
            let trackIDs = foundTracks.compactMap { $0.spotifyID }
            if !trackIDs.isEmpty {
                spotifyPlaylistID = try? await spotifyService.createPlaylist(
                    name: trimmedName,
                    description: "Created by GrooveWire",
                    trackIDs: trackIDs
                )
            }
        }

        let savedPlaylist = SavedPlaylist(
            name: trimmedName,
            spotifyPlaylistID: spotifyPlaylistID,
            playlistDescription: "Created by GrooveWire",
            isPublic: false
        )
        modelContext.insert(savedPlaylist)

        for track in foundTracks {
            let localTrack = Track(
                title: track.title,
                artist: track.artist,
                albumTitle: track.albumTitle,
                artworkURL: track.artworkURL,
                appleMusicID: track.appleMusicID,
                spotifyID: track.spotifyID,
                durationSeconds: track.durationSeconds
            )
            localTrack.savedPlaylist = savedPlaylist
            modelContext.insert(localTrack)
            savedPlaylist.trackList.append(localTrack)
        }

        do {
            try modelContext.save()
            if !notFound.isEmpty {
                statusMessage = "Created! \(notFound.count) song(s) not found."
            }
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func parsedSongCount(from text: String) -> Int {
        PlaylistParser.parseSongEntries(from: text).count
    }
}

// MARK: - Shared Parsing Utility (consolidated from duplicates)

enum PlaylistParser {
    struct SongEntry {
        let title: String
        let artist: String
    }

    static func parseSongEntries(from text: String) -> [SongEntry] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.contains(where: { $0.hasPrefix("#EXTINF:") }) {
            return parseM3U(lines)
        }
        return parseCSV(lines)
    }

    static func parseCSV(_ lines: [String]) -> [SongEntry] {
        var mutable = lines
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

    static func parseM3U(_ lines: [String]) -> [SongEntry] {
        return lines.compactMap { line in
            guard line.hasPrefix("#EXTINF:") else { return nil }
            guard let commaIndex = line.firstIndex(of: ",") else { return nil }
            let displayText = String(line[line.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)

            if let dashRange = displayText.range(of: " - ") {
                let artist = String(displayText[displayText.startIndex..<dashRange.lowerBound])
                let title = String(displayText[dashRange.upperBound...])
                return SongEntry(title: title, artist: artist)
            }
            return nil
        }
    }
}

// MARK: - M3U UTType

extension UTType {
    static let m3uPlaylist = UTType(filenameExtension: "m3u") ?? .plainText
}
