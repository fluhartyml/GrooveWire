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
    @State private var waitingForConfirmation = false
    @State private var lastResult: PlaylistTransferResult?
    @State private var transferContinuation: CheckedContinuation<Void, Never>?

    enum PlaylistTransferResult {
        case success(name: String, matched: Int, total: Int)
        case failed(name: String)
    }

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

                if !isDone && !isTransferring && !waitingForConfirmation {
                    Section("Transfer To") {
                        HStack {
                            if spotifyService.isConnected && sourceService != .spotify {
                                Button {
                                    targetService = .spotify
                                    startStepTransfer()
                                } label: {
                                    Label("Spotify", systemImage: "antenna.radiowaves.left.and.right")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            }
                            if appleMusicService.isConnected && sourceService != .appleMusic {
                                Button {
                                    targetService = .appleMusic
                                    startStepTransfer()
                                } label: {
                                    Label("Apple Music", systemImage: "apple.logo")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.pink)
                            }
                        }
                        Text("Transfers one at a time with pass/fail")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

                if waitingForConfirmation, let result = lastResult {
                    Section {
                        VStack(spacing: 12) {
                            switch result {
                            case .success(let name, let matched, let total):
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.green)
                                Text(name)
                                    .font(.headline)
                                Text("\(matched)/\(total) tracks matched")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            case .failed(let name):
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.red)
                                Text(name)
                                    .font(.headline)
                                Text("Transfer failed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text("\(currentPlaylistIndex + 1) of \(playlists.count)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }

                    Section {
                        if currentPlaylistIndex < playlists.count - 1 {
                            Button {
                                waitingForConfirmation = false
                                transferContinuation?.resume()
                                transferContinuation = nil
                            } label: {
                                Label("Next Playlist", systemImage: "arrow.right")
                            }
                        }
                        Button("Done") {
                            transferContinuation?.resume()
                            transferContinuation = nil
                            dismiss()
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
                ToolbarItem(placement: .confirmationAction) {
                    if !isDone && !isTransferring && !waitingForConfirmation {
                        Button {
                            startBatchTransfer()
                        } label: {
                            Text("Transfer All")
                        }
                    }
                }
            }
        }
        .onAppear {
            targetService = sourceService == .spotify ? .appleMusic : .spotify
        }
    }

    private func startStepTransfer() {
        isTransferring = true
        Task {
            for (index, playlist) in playlists.enumerated() {
                await MainActor.run {
                    currentPlaylistIndex = index
                    currentPlaylistName = playlist.name
                    waitingForConfirmation = false
                }

                let result = await transferSinglePlaylist(playlist)

                await MainActor.run {
                    lastResult = result
                    isTransferring = false
                    waitingForConfirmation = true
                    switch result {
                    case .success: completedCount += 1
                    case .failed(let name): failedNames.append(name)
                    }
                }

                // Wait for user to tap Next or Done
                if index < playlists.count - 1 {
                    await withCheckedContinuation { continuation in
                        Task { @MainActor in
                            transferContinuation = continuation
                        }
                    }
                    // Buffer before next playlist
                    try? await Task.sleep(for: .seconds(2))
                    await MainActor.run { isTransferring = true }
                }
            }

            await MainActor.run {
                isTransferring = false
                waitingForConfirmation = false
                isDone = true
            }
        }
    }

    private func transferSinglePlaylist(_ playlist: SavedPlaylist) async -> PlaylistTransferResult {
        do {
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
                return .failed(name: playlist.name)
            }

            let description = "Transferred by GrooveWire"

            switch targetService {
            case .spotify:
                let newID = try await spotifyService.createPlaylist(
                    name: playlist.name, description: description, trackIDs: trackIDs
                )
                playlist.spotifyPlaylistID = newID
            case .appleMusic:
                let newID = try await appleMusicService.createPlaylist(
                    name: playlist.name, description: description, trackIDs: trackIDs
                )
                playlist.appleMusicPlaylistID = newID
            case .none:
                break
            }

            for result in matched {
                if let matchedTrack = result.matchedTrack {
                    switch targetService {
                    case .spotify: result.originalTrack.spotifyID = matchedTrack.spotifyID
                    case .appleMusic: result.originalTrack.appleMusicID = matchedTrack.appleMusicID
                    case .none: break
                    }
                    result.originalTrack.matchConfidence = result.confidence
                }
            }

            try modelContext.save()
            return .success(name: playlist.name, matched: matched.count, total: playlist.trackList.count)

        } catch {
            return .failed(name: playlist.name)
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

                // Buffer between playlists to avoid Spotify rate limiting
                if index < playlists.count - 1 {
                    try? await Task.sleep(for: .seconds(3))
                }
            }

            await MainActor.run {
                isTransferring = false
                isDone = true
            }
        }
    }
}
