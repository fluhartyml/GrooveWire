import SwiftUI
import SwiftData

// MARK: - Transfer Phase

enum TransferPhase {
    case configure
    case matching
    case review
    case creating
    case complete
    case failed
}

// MARK: - PlaylistTransferSheet

struct PlaylistTransferSheet: View {
    let playlist: SavedPlaylist

    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(TrackMatchingService.self) private var trackMatchingService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var phase: TransferPhase = .configure
    @State private var targetService: StreamingService = .spotify
    @State private var matchResults: [TrackMatchResult] = []
    @State private var selectedResultIDs: Set<UUID> = []
    @State private var errorMessage: String?
    @State private var createdTrackCount: Int = 0
    @State private var matchTask: Task<Void, Never>?

    // MARK: - Computed

    private var sourceService: StreamingService {
        let tracks = playlist.trackList
        let spotifyCount = tracks.filter { $0.spotifyID != nil }.count
        let appleCount = tracks.filter { $0.appleMusicID != nil }.count
        return spotifyCount >= appleCount ? .spotify : .appleMusic
    }

    private var exactCount: Int { matchResults.filter { $0.confidence == .exact }.count }
    private var nearCount: Int { matchResults.filter { $0.confidence == .near }.count }
    private var noMatchCount: Int { matchResults.filter { $0.confidence == .noMatch }.count }
    private var transferCount: Int { selectedResultIDs.count }

    private var canMatch: Bool {
        switch targetService {
        case .spotify: return spotifyService.isConnected
        case .appleMusic: return appleMusicService.isConnected
        case .none: return false
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                sourceSection
                phaseContent
            }
            .formStyle(.grouped)
            .navigationTitle("Transfer Playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        matchTask?.cancel()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Default target to the opposite of the source
            targetService = sourceService == .spotify ? .appleMusic : .spotify
        }
    }

    // MARK: - Source Info

    @ViewBuilder
    private var sourceSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "music.note.list")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.headline)
                    HStack(spacing: 6) {
                        Text("\(playlist.trackCount) tracks")
                        Text("·")
                        serviceLabel(sourceService)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Phase Content

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .configure:
            configureSection
        case .matching:
            matchingSection
        case .review:
            reviewSection
        case .creating:
            creatingSection
        case .complete:
            completeSection
        case .failed:
            failedSection
        }
    }

    // MARK: - Configure

    private var canCreateOnAppleMusic: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }

    @ViewBuilder
    private var configureSection: some View {
        Section("Transfer To") {
            Picker("Target", selection: $targetService) {
                if spotifyService.isConnected && sourceService != .spotify {
                    Text("Spotify").tag(StreamingService.spotify)
                }
                if appleMusicService.isConnected && sourceService != .appleMusic && canCreateOnAppleMusic {
                    Text("Apple Music").tag(StreamingService.appleMusic)
                }
            }
            .pickerStyle(.segmented)

            if !canMatch {
                Label("Connect \(targetService.displayName) to transfer", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            #if os(macOS)
            if sourceService == .spotify && appleMusicService.isConnected {
                Label("Transfer to Apple Music available on iPhone/iPad", systemImage: "iphone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            #endif
        }

        Section {
            Button {
                startMatching()
            } label: {
                Label("Match Tracks", systemImage: "wand.and.stars")
            }
            .disabled(!canMatch || playlist.trackList.isEmpty)
        }
    }

    // MARK: - Matching

    @ViewBuilder
    private var matchingSection: some View {
        Section("Matching Tracks") {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: trackMatchingService.matchProgress)
                    .tint(.orange)

                let matched = Int(trackMatchingService.matchProgress * Double(playlist.trackCount))
                Text("Matching track \(matched) of \(playlist.trackCount)...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Review

    @ViewBuilder
    private var reviewSection: some View {
        Section("Results") {
            HStack(spacing: 16) {
                matchBadge(count: exactCount, color: .green, label: "Exact")
                matchBadge(count: nearCount, color: .yellow, label: "Near")
                matchBadge(count: noMatchCount, color: .red, label: "Not Found")
            }
        }

        Section("Tracks") {
            ForEach(matchResults) { result in
                matchResultRow(result)
            }
        }

        Section {
            Button {
                startCreating()
            } label: {
                Label("Create Playlist on \(targetService.displayName)", systemImage: "plus.circle.fill")
            }
            .disabled(transferCount == 0)

            Text("Will transfer \(transferCount) of \(matchResults.count) tracks")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Creating

    @ViewBuilder
    private var creatingSection: some View {
        Section {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                Text("Creating playlist on \(targetService.displayName)...")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Complete

    @ViewBuilder
    private var completeSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text("Playlist created on \(targetService.displayName)")
                    .font(.headline)

                Text("\(createdTrackCount) tracks transferred")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

    // MARK: - Failed

    @ViewBuilder
    private var failedSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Transfer Failed", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.headline)

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Section {
            Button("Try Again") {
                phase = .configure
                errorMessage = nil
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func matchBadge(count: Int, color: Color, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func matchResultRow(_ result: TrackMatchResult) -> some View {
        HStack(spacing: 10) {
            confidenceIcon(result.confidence)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.originalTrack.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(result.originalTrack.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if result.confidence == .near, let matched = result.matchedTrack {
                    Text("→ \(matched.title) — \(matched.artist)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }

            Spacer()

            if result.confidence != .noMatch {
                Toggle("", isOn: Binding(
                    get: { selectedResultIDs.contains(result.id) },
                    set: { isOn in
                        if isOn {
                            selectedResultIDs.insert(result.id)
                        } else {
                            selectedResultIDs.remove(result.id)
                        }
                    }
                ))
                .labelsHidden()
            }
        }
        .opacity(result.confidence == .noMatch ? 0.5 : 1.0)
    }

    @ViewBuilder
    private func confidenceIcon(_ confidence: MatchConfidence) -> some View {
        switch confidence {
        case .exact:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .near:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        case .noMatch:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private func serviceLabel(_ service: StreamingService) -> some View {
        switch service {
        case .spotify:
            Label("Spotify", systemImage: "dot.radiowaves.left.and.right")
                .foregroundStyle(.green)
        case .appleMusic:
            Label("Apple Music", systemImage: "apple.logo")
                .foregroundStyle(.mint)
        case .none:
            Text("Unknown")
        }
    }

    // MARK: - Actions

    private func startMatching() {
        phase = .matching
        matchTask = Task {
            let results = await trackMatchingService.matchPlaylist(playlist.trackList, to: targetService)
            await MainActor.run {
                matchResults = results
                // Pre-select exact and near matches
                selectedResultIDs = Set(results.filter { $0.confidence != .noMatch }.map { $0.id })
                phase = .review
            }
        }
    }

    private func startCreating() {
        phase = .creating
        Task {
            let selected = matchResults.filter { selectedResultIDs.contains($0.id) }
            let trackIDs: [String] = selected.compactMap { result in
                guard let matched = result.matchedTrack else { return nil }
                switch targetService {
                case .spotify: return matched.spotifyID
                case .appleMusic: return matched.appleMusicID
                case .none: return nil
                }
            }

            guard !trackIDs.isEmpty else {
                await MainActor.run {
                    errorMessage = "No tracks to transfer."
                    phase = .failed
                }
                return
            }

            do {
                let playlistName = playlist.name
                let description = "Transferred by GrooveWire"

                switch targetService {
                case .spotify:
                    let newID = try await spotifyService.createPlaylist(
                        name: playlistName,
                        description: description,
                        trackIDs: trackIDs
                    )
                    playlist.spotifyPlaylistID = newID

                case .appleMusic:
                    let newID = try await appleMusicService.createPlaylist(
                        name: playlistName,
                        description: description,
                        trackIDs: trackIDs
                    )
                    playlist.appleMusicPlaylistID = newID

                case .none:
                    break
                }

                // Update track models with matched IDs
                for result in selected {
                    if let matched = result.matchedTrack {
                        switch targetService {
                        case .spotify:
                            result.originalTrack.spotifyID = matched.spotifyID
                        case .appleMusic:
                            result.originalTrack.appleMusicID = matched.appleMusicID
                        case .none:
                            break
                        }
                        result.originalTrack.matchConfidence = result.confidence
                    }
                }

                try modelContext.save()

                await MainActor.run {
                    createdTrackCount = trackIDs.count
                    phase = .complete
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    phase = .failed
                }
            }
        }
    }
}
