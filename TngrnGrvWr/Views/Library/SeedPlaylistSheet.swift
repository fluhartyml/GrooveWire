import SwiftUI
import SwiftData

/// Seed-from-song playlist builder.
/// Pick a song, fetch recommendations, review/edit, then save as an editable playlist.
struct SeedPlaylistSheet: View {
    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(TrackMatchingService.self) private var matchingService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor

    @State private var searchQuery = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchTask: Task<Void, Never>?

    @State private var seedTrack: Track?
    @State private var recommendations: [Track] = []
    @State private var isFetchingRecs = false
    @State private var selectedTracks: Set<UUID> = []

    @State private var playlistName = ""
    @State private var isSaving = false
    @State private var savedMessage: String?
    @State private var error: String?

    enum Phase { case search, review, name }
    @State private var phase: Phase = .search

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .search:
                    searchPhase
                case .review:
                    reviewPhase
                case .name:
                    namePhase
                }
            }
            .navigationTitle(phaseTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var phaseTitle: String {
        switch phase {
        case .search: "Pick a Seed Song"
        case .review: "Build Your Playlist"
        case .name: "Name Your Playlist"
        }
    }

    // MARK: - Search Phase

    @ViewBuilder
    private var searchPhase: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search for a song to build around...", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { performSearch() }
                    .onChange(of: searchQuery) { _, newValue in
                        searchTask?.cancel()
                        guard !newValue.isEmpty else {
                            searchResults = []
                            hasSearched = false
                            return
                        }
                        searchTask = Task {
                            try? await Task.sleep(for: .milliseconds(600))
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                isSearching = true
                                hasSearched = true
                                error = nil
                            }
                            guard !Task.isCancelled else { return }
                            let query = newValue
                            do {
                                let results: [Track]
                                if appleMusicService.isConnected {
                                    results = try await appleMusicService.search(query: query)
                                } else if spotifyService.isConnected {
                                    results = try await spotifyService.search(query: query)
                                } else {
                                    results = []
                                }
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    searchResults = results
                                    isSearching = false
                                }
                            } catch {
                                guard !Task.isCancelled else { return }
                                await MainActor.run { isSearching = false }
                            }
                        }
                    }

                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding()

            List {
                if searchResults.isEmpty && !isSearching && hasSearched {
                    ContentUnavailableView.search(text: searchQuery)
                }

                ForEach(searchResults) { track in
                    Button {
                        seedTrack = track
                        fetchRecommendations(for: track)
                    } label: {
                        HStack {
                            TrackRow(track: track)
                            Spacer()
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(themeColor)
                        }
                    }
                    .tint(.primary)
                }
            }
            .overlay {
                if isSearching {
                    ProgressView("Searching...")
                }
            }
        }
    }

    // MARK: - Review Phase

    @ViewBuilder
    private var reviewPhase: some View {
        VStack(spacing: 0) {
            if let seed = seedTrack {
                // Seed track header
                HStack(spacing: 12) {
                    if let url = seed.artworkURL, let imageURL = URL(string: url) {
                        AsyncImage(url: imageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Seeded from:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(seed.title)
                            .font(.headline)
                        Text(seed.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Change") {
                        phase = .search
                        recommendations = []
                        selectedTracks = []
                    }
                    .font(.caption)
                }
                .padding()
            }

            if isFetchingRecs {
                Spacer()
                ProgressView("Finding similar songs...")
                Spacer()
            } else {
                // Select all / none toolbar
                HStack {
                    Text("\(selectedTracks.count) of \(recommendations.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Select All") {
                        selectedTracks = Set(recommendations.map { $0.id })
                    }
                    .font(.caption)
                    Button("Clear") {
                        selectedTracks = []
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)

                List {
                    ForEach(recommendations) { track in
                        Button {
                            if selectedTracks.contains(track.id) {
                                selectedTracks.remove(track.id)
                            } else {
                                selectedTracks.insert(track.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedTracks.contains(track.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedTracks.contains(track.id) ? .orange : .secondary)
                                TrackRow(track: track)
                            }
                        }
                        .tint(.primary)
                    }
                }

                Button {
                    phase = .name
                    if let seed = seedTrack {
                        playlistName = "Built from \(seed.title)"
                    }
                } label: {
                    Text("Next: Name Playlist (\(selectedTracks.count) tracks)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeColor)
                .disabled(selectedTracks.isEmpty)
                .padding()
            }
        }
    }

    // MARK: - Name Phase

    @ViewBuilder
    private var namePhase: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(themeColor)

            Text("\(selectedTracks.count) tracks ready")
                .font(.headline)

            TextField("Playlist name", text: $playlistName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)

            if let msg = savedMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Button {
                Task { await savePlaylist() }
            } label: {
                if isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create Playlist")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColor)
            .disabled(playlistName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            .padding(.horizontal, 40)

            Button("Back") {
                phase = .review
                savedMessage = nil
            }
            .font(.caption)

            Spacer()
        }
    }

    // MARK: - Actions

    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        hasSearched = true
        error = nil

        Task {
            do {
                if appleMusicService.isConnected {
                    searchResults = try await appleMusicService.search(query: searchQuery)
                } else if spotifyService.isConnected {
                    searchResults = try await spotifyService.search(query: searchQuery)
                } else {
                    error = "Connect a streaming service in Profile to search."
                }
            } catch {
                self.error = error.localizedDescription
            }
            isSearching = false
        }
    }

    private func fetchRecommendations(for track: Track) {
        isFetchingRecs = true
        phase = .review

        Task {
            do {
                var recs: [Track] = []

                // Apple Music genre-based recommendations (different artists, same genre)
                if appleMusicService.isConnected, let appleMusicID = track.appleMusicID {
                    recs = try await appleMusicService.getRecommendations(seedTrackID: appleMusicID, limit: 25)
                }

                // Fallback: Spotify related artist search
                if recs.isEmpty, spotifyService.isConnected {
                    recs = try await spotifyService.search(query: "\(track.artist) \(track.title)")
                    recs = recs.filter { $0.spotifyID != track.spotifyID }
                    recs = Array(recs.prefix(25))
                }

                recommendations = recs
                // Pre-select all by default
                selectedTracks = Set(recs.map { $0.id })
            } catch {
                self.error = "Failed to get recommendations: \(error.localizedDescription)"
            }
            isFetchingRecs = false
        }
    }

    private func savePlaylist() async {
        let name = playlistName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        let tracksToSave = recommendations.filter { selectedTracks.contains($0.id) }

        // Include the seed track at position 0
        var allTracks: [Track] = []
        if let seed = seedTrack {
            allTracks.append(seed)
        }
        allTracks.append(contentsOf: tracksToSave)

        // Create on Spotify if connected
        var spotifyPlaylistID: String?
        if spotifyService.isConnected {
            let spotifyIDs = allTracks.compactMap { $0.spotifyID }
            if !spotifyIDs.isEmpty {
                do {
                    spotifyPlaylistID = try await spotifyService.createPlaylist(
                        name: name,
                        description: "Built from \(seedTrack?.title ?? "a seed song") via GrooveWire",
                        trackIDs: spotifyIDs
                    )
                } catch {
                    print("[SeedPlaylist] Spotify creation failed: \(error.localizedDescription)")
                }
            }
        }

        // Save locally
        let playlist = SavedPlaylist(
            name: name,
            spotifyPlaylistID: spotifyPlaylistID,
            playlistDescription: "Built from \(seedTrack?.title ?? "a seed song")",
            isPublic: false
        )
        modelContext.insert(playlist)

        for track in allTracks {
            let localTrack = Track(
                title: track.title,
                artist: track.artist,
                albumTitle: track.albumTitle,
                artworkURL: track.artworkURL,
                appleMusicID: track.appleMusicID,
                spotifyID: track.spotifyID,
                durationSeconds: track.durationSeconds,
                addedBy: track.addedBy
            )
            localTrack.savedPlaylist = playlist
            modelContext.insert(localTrack)
            playlist.trackList.append(localTrack)
        }

        do {
            try modelContext.save()
            savedMessage = "Created '\(name)' with \(allTracks.count) tracks!"
            // Auto-dismiss after brief delay
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
        }
    }
}
