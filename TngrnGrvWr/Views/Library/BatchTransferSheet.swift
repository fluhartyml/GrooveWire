import SwiftUI
import SwiftData

struct BatchTransferSheet: View {
    let playlists: [SavedPlaylist]

    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(TrackMatchingService.self) private var trackMatchingService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor

    @State private var targetService: StreamingService = .spotify
    @State private var isTransferring = false
    @State private var currentPlaylistIndex = 0
    @State private var currentPlaylistName = ""
    @State private var completedCount = 0
    @State private var failedNames: [String] = []
    @State private var isDone = false

    private var sourceService: StreamingService {
        let allTracks = playlists.flatMap { $0.trackList }
        let spotifyCount = allTracks.filter { $0.spotifyID != nil }.count
        let appleCount = allTracks.filter { $0.appleMusicID != nil }.count
        return spotifyCount >= appleCount ? .spotify : .appleMusic
    }

    private var totalTracks: Int {
        playlists.reduce(0) { $0 + $1.trackCount }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(playlists.count) playlists selected")
                            .font(.headline)
                        Text("\(totalTracks) total tracks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !isDone && !isTransferring {
                    Section("Transfer To") {
                        Picker("Target", selection: $targetService) {
                            if spotifyService.isConnected && sourceService != .spotify {
                                Text("Spotify").tag(StreamingService.spotify)
                            }
                            if appleMusicService.isConnected && sourceService != .appleMusic {
                                Text("Apple Music").tag(StreamingService.appleMusic)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section {
                        Button {
                            startBatchTransfer()
                        } label: {
                            Label("Transfer All", systemImage: "arrow.triangle.swap")
                        }
                    }
                }

                if isTransferring {
                    Section("Transferring...") {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: Double(currentPlaylistIndex), total: Double(playlists.count))
                                .tint(themeColor)

                            Text("Matching \"\(currentPlaylistName)\" (\(currentPlaylistIndex + 1) of \(playlists.count))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if isDone {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.green)

                            Text("Transferred \(completedCount) of \(playlists.count) playlists")
                                .font(.headline)

                            if !failedNames.isEmpty {
                                Text("Failed: \(failedNames.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }

                    Section {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Batch Transfer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !isTransferring {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
        .onAppear {
            targetService = sourceService == .spotify ? .appleMusic : .spotify
        }
    }

    private func startBatchTransfer() {
        isTransferring = true
        Task {
            for (index, playlist) in playlists.enumerated() {
                await MainActor.run {
                    currentPlaylistIndex = index
                    currentPlaylistName = playlist.name
                }

                do {
                    // Match tracks
                    let results = await trackMatchingService.matchPlaylist(playlist.trackList, to: targetService)
                    let matched = results.filter { $0.confidence != .noMatch }

                    let trackIDs: [String] = matched.compactMap { result in
                        guard let matchedTrack = result.matchedTrack else { return nil }
                        switch targetService {
                        case .spotify: return matchedTrack.spotifyID
                        case .appleMusic: return matchedTrack.appleMusicID
                        case .none: return nil
                        }
                    }

                    guard !trackIDs.isEmpty else {
                        await MainActor.run { failedNames.append(playlist.name) }
                        continue
                    }

                    // Create playlist on target
                    let description = "Transferred by GrooveWire"

                    switch targetService {
                    case .spotify:
                        let newID = try await spotifyService.createPlaylist(
                            name: playlist.name,
                            description: description,
                            trackIDs: trackIDs
                        )
                        playlist.spotifyPlaylistID = newID

                    case .appleMusic:
                        let newID = try await appleMusicService.createPlaylist(
                            name: playlist.name,
                            description: description,
                            trackIDs: trackIDs
                        )
                        playlist.appleMusicPlaylistID = newID

                    case .none:
                        break
                    }

                    // Update track models with matched IDs
                    for result in matched {
                        if let matchedTrack = result.matchedTrack {
                            switch targetService {
                            case .spotify:
                                result.originalTrack.spotifyID = matchedTrack.spotifyID
                            case .appleMusic:
                                result.originalTrack.appleMusicID = matchedTrack.appleMusicID
                            case .none:
                                break
                            }
                            result.originalTrack.matchConfidence = result.confidence
                        }
                    }

                    try modelContext.save()
                    await MainActor.run { completedCount += 1 }

                } catch {
                    await MainActor.run { failedNames.append(playlist.name) }
                }
            }

            await MainActor.run {
                isTransferring = false
                isDone = true
            }
        }
    }
}
