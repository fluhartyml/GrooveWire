import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum AddToBridgeMode: String, CaseIterable {
    case library = "My Library"
    case link = "Paste Link"
    case songs = "Import Songs"
    case file = "Import File"
}

struct AddPlaylistToBridgeSheet: View {
    let bridge: Bridge
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Query(sort: \SavedPlaylist.createdAt, order: .reverse) private var savedPlaylists: [SavedPlaylist]
    @State private var mode: AddToBridgeMode = .library

    // Link mode
    @State private var linkText = ""

    // Songs mode (manual text entry)
    @State private var songsText = ""

    // File mode
    @State private var fileContents = ""
    @State private var fileName = ""
    @State private var showFilePicker = false

    @State private var isLoading = false
    @State private var statusMessage = ""
    @State private var errorMessage: String?
    @State private var addedCount = 0

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $mode) {
                    ForEach(AddToBridgeMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                switch mode {
                case .library:
                    if savedPlaylists.isEmpty {
                        Section {
                            Text("No saved playlists yet. Sync from Spotify in My Library.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section("Select a Playlist") {
                            ForEach(savedPlaylists) { playlist in
                                Button {
                                    loadPlaylistIntoBridge(playlist)
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
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(themeColor)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

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
                            if fileName.isEmpty {
                                Text("No file selected")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(fileName)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button("Browse...") {
                                showFilePicker = true
                            }
                        }
                    } header: {
                        Text("Import File")
                    } footer: {
                        Text("Supports CSV and M3U playlist files.")
                    }

                    if !fileContents.isEmpty {
                        Section {
                            let count = parsedSongCount(from: fileContents)
                            Label("\(count) songs detected", systemImage: "music.note.list")
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
                    }
                }

                if addedCount > 0 {
                    Section {
                        Label("Added \(addedCount) tracks to \(bridge.name)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Playlist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
                            Task { await importTracks() }
                        }
                        .disabled(isImportDisabled)
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
                fileName = url.lastPathComponent
            case .failure(let error):
                errorMessage = "Couldn't open file: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Load from Library

    private func loadPlaylistIntoBridge(_ playlist: SavedPlaylist) {
        for track in playlist.trackList {
            let newTrack = Track(
                title: track.title,
                artist: track.artist,
                albumTitle: track.albumTitle,
                artworkURL: track.artworkURL,
                appleMusicID: track.appleMusicID,
                spotifyID: track.spotifyID,
                durationSeconds: track.durationSeconds,
                addedBy: bridge.hostID
            )
            bridge.trackList.append(newTrack)
            modelContext.insert(newTrack)
        }
        try? modelContext.save()
        addedCount = playlist.trackCount
        print("[Bridge] Loaded '\(playlist.name)' (\(playlist.trackCount) tracks) into '\(bridge.name)'")

        Task {
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        }
    }

    // MARK: - Validation

    private var isImportDisabled: Bool {
        switch mode {
        case .library:
            return true // library uses per-row buttons, not the Import button
        case .link:
            return linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
        case .songs:
            return songsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
        case .file:
            return fileContents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading
        }
    }

    // MARK: - Import

    private func importTracks() async {
        switch mode {
        case .library:
            break // handled by per-row buttons
        case .link:
            await importFromLink()
        case .songs:
            await importFromText(songsText)
        case .file:
            await importFromText(fileContents)
        }
    }

    private func importFromLink() async {
        let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let playlistID = SpotifyService.playlistID(from: trimmed) else {
            errorMessage = "Couldn't find a playlist ID in that link. Make sure it's a Spotify playlist URL."
            return
        }

        guard spotifyService.isConnected else {
            errorMessage = "Connect Spotify in your Profile to import playlist links."
            return
        }

        isLoading = true
        errorMessage = nil
        statusMessage = "Fetching playlist tracks..."

        do {
            let tracks = try await spotifyService.fetchPlaylistTracks(playlistID: playlistID)

            for track in tracks {
                let newTrack = Track(
                    title: track.title,
                    artist: track.artist,
                    albumTitle: track.albumTitle,
                    artworkURL: track.artworkURL,
                    spotifyID: track.spotifyID,
                    durationSeconds: track.durationSeconds,
                    addedBy: bridge.hostID
                )
                bridge.trackList.append(newTrack)
                modelContext.insert(newTrack)
            }

            try modelContext.save()
            addedCount = tracks.count
            statusMessage = ""
            print("[Bridge] Added \(tracks.count) tracks from Spotify playlist to '\(bridge.name)'")

            // Brief delay so user sees the success message, then dismiss
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch {
            errorMessage = "Failed to fetch playlist: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func importFromText(_ rawText: String) async {
        let songEntries = parseSongEntries(from: rawText)

        guard !songEntries.isEmpty else {
            errorMessage = "No songs found. Enter one song per line: Title, Artist"
            return
        }

        isLoading = true
        errorMessage = nil
        var addedTracks: [Track] = []
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
                    let newTrack = Track(
                        title: match.title,
                        artist: match.artist,
                        albumTitle: match.albumTitle,
                        artworkURL: match.artworkURL,
                        appleMusicID: match.appleMusicID,
                        spotifyID: match.spotifyID,
                        durationSeconds: match.durationSeconds,
                        addedBy: bridge.hostID
                    )
                    bridge.trackList.append(newTrack)
                    modelContext.insert(newTrack)
                    addedTracks.append(newTrack)
                } else {
                    notFound.append("\(entry.title) — \(entry.artist)")
                }
            } catch {
                notFound.append("\(entry.title) — \(entry.artist)")
            }
        }

        if addedTracks.isEmpty {
            errorMessage = "Couldn't find any of those songs."
            isLoading = false
            return
        }

        do {
            try modelContext.save()
            addedCount = addedTracks.count
            print("[Bridge] Added \(addedTracks.count) tracks to '\(bridge.name)' from text import")

            if !notFound.isEmpty {
                statusMessage = "\(notFound.count) song(s) not found: \(notFound.joined(separator: ", "))"
            } else {
                statusMessage = ""
            }

            // Brief delay so user sees the success message, then dismiss
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
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

    private func parsedSongCount(from text: String) -> Int {
        parseSongEntries(from: text).count
    }
}

#Preview {
    AddPlaylistToBridgeSheet(bridge: Bridge(name: "Test Bridge", hostID: UUID()))
}
