import SwiftUI
import SwiftData
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct PlaylistTransferToMusicSheet: View {
    let playlist: SavedPlaylist

    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(TrackMatchingService.self) private var trackMatchingService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor

    // Phase: matching → review → export → complete/failed
    enum Phase {
        case matching
        case review
        case export
        case complete
        case failed
    }

    @State private var phase: Phase = .matching
    @State private var matchResults: [TrackMatchResult] = []
    @State private var selectedResultIDs: Set<UUID> = []
    @State private var overrides: [UUID: Track] = [:]
    @State private var errorMessage: String?
    @State private var exportedCount: Int = 0
    @State private var m3uURL: URL?
    @State private var savedToDownloads: Bool = false
    @State private var copiedLink: Bool = false

    // Song picker state
    @State private var pickerTargetResultID: UUID?
    @State private var pickerQuery: String = ""
    @State private var pickerResults: [Track] = []
    @State private var isSearching: Bool = false

    // MARK: - Computed

    private var exactCount: Int { matchResults.filter { $0.confidence == .exact }.count }
    private var nearCount: Int { matchResults.filter { $0.confidence == .near }.count }
    private var noMatchCount: Int {
        matchResults.filter { $0.confidence == .noMatch && overrides[$0.id] == nil }.count
    }
    private var overriddenCount: Int { overrides.count }
    private var transferCount: Int { selectedResultIDs.count }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .matching:
                    matchingView
                case .review:
                    reviewView
                case .export:
                    exportView
                case .complete:
                    completeView
                case .failed:
                    failedView
                }
            }
            .navigationTitle("Transfer to Apple Music")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(phase == .complete ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 450)
        .task {
            await runMatching()
        }
    }

    // MARK: - Matching Phase

    private var matchingView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wand.and.stars")
                .font(.system(size: 48))
                .foregroundStyle(themeColor)

            Text("Matching \(playlist.trackCount) tracks to Apple Music...")
                .font(.headline)

            ProgressView(value: trackMatchingService.matchProgress)
                .tint(themeColor)
                .padding(.horizontal, 40)

            let matched = Int(trackMatchingService.matchProgress * Double(playlist.trackCount))
            Text("Track \(matched) of \(playlist.trackCount)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Review Phase

    private var reviewView: some View {
        Form {
            // Summary
            Section {
                HStack(spacing: 16) {
                    summaryBadge(count: exactCount, color: .green, label: "Exact")
                    summaryBadge(count: nearCount, color: .yellow, label: "Near")
                    if overriddenCount > 0 {
                        summaryBadge(count: overriddenCount, color: .blue, label: "Picked")
                    }
                    summaryBadge(count: noMatchCount, color: .red, label: "Unmatched")
                }
                .frame(maxWidth: .infinity)
            }

            // Track list
            Section("Tracks (\(transferCount) selected)") {
                ForEach(matchResults) { result in
                    trackRow(result)
                }
            }

            // Continue button
            Section {
                Button {
                    generateM3U()
                    phase = .export
                } label: {
                    Label("Continue to Export", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(themeColor)
                .disabled(transferCount == 0)

                Text("\(transferCount) tracks ready to export")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Export Phase (options sheet)

    private var exportView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(themeColor)

            Text(playlist.name)
                .font(.headline)

            Text("\(exportedCount) tracks matched to Apple Music")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let matchInfo = matchSummaryText {
                Text(matchInfo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Option 1: Open in Music
            #if os(macOS)
            Button {
                saveToDownloadsAndOpenInMusic()
            } label: {
                Label("Save & Open in Music", systemImage: "music.note")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColor)
            #endif

            // Option 2: Save to file (NSSavePanel)
            #if os(macOS)
            Button {
                saveToFile()
            } label: {
                Label("Save M3U to...", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            #endif

            // Option 3: Share
            if let m3uURL {
                ShareLink(
                    item: m3uURL,
                    preview: SharePreview(playlist.name, image: Image(systemName: "music.note.list"))
                ) {
                    Label("Share via AirDrop / Messages", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            // Option 4: Copy Spotify Link
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

            // Back to review
            Button {
                phase = .review
            } label: {
                Text("Back to Review")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Complete Phase

    private var completeView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Playlist transferred")
                .font(.headline)

            Text("\(exportedCount) tracks exported")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if savedToDownloads {
                Label("M3U saved to Downloads", systemImage: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(themeColor)
        }
        .padding()
    }

    // MARK: - Failed Phase

    private var failedView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Export Failed")
                .font(.headline)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Back to Review") {
                    phase = .review
                    errorMessage = nil
                }
                .buttonStyle(.bordered)

                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(themeColor)
            }
        }
        .padding()
    }

    // MARK: - Track Row

    @ViewBuilder
    private func trackRow(_ result: TrackMatchResult) -> some View {
        let hasOverride = overrides[result.id] != nil
        let effectiveConfidence: MatchConfidence = hasOverride ? .exact : result.confidence
        let isSelected = selectedResultIDs.contains(result.id)

        HStack(spacing: 10) {
            confidenceIcon(effectiveConfidence)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.originalTrack.title)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(result.originalTrack.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let override = overrides[result.id] {
                    Text("\u{2192} \(override.title) \u{2014} \(override.artist)")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                } else if result.confidence == .near, let matched = result.matchedTrack {
                    Text("\u{2192} \(matched.title) \u{2014} \(matched.artist)")
                        .font(.caption2)
                        .foregroundStyle(themeColor)
                        .lineLimit(1)
                } else if result.confidence == .noMatch {
                    Text("No match found")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                }
            }

            Spacer()

            if result.confidence == .near || result.confidence == .noMatch {
                Button {
                    openPicker(for: result)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .popover(isPresented: Binding(
                    get: { pickerTargetResultID == result.id },
                    set: { if !$0 { pickerTargetResultID = nil } }
                )) {
                    songPickerPopover(for: result)
                }
            }

            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { on in
                    if on {
                        selectedResultIDs.insert(result.id)
                    } else {
                        selectedResultIDs.remove(result.id)
                    }
                }
            ))
            .labelsHidden()
        }
        .opacity(effectiveConfidence == .noMatch ? 0.5 : 1.0)
    }

    // MARK: - Song Picker Popover

    private func songPickerPopover(for result: TrackMatchResult) -> some View {
        VStack(spacing: 12) {
            Text("Find on Apple Music")
                .font(.headline)

            HStack {
                TextField("Search...", text: $pickerQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { searchAppleMusic() }

                Button {
                    searchAppleMusic()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .disabled(pickerQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if pickerResults.isEmpty && !pickerQuery.isEmpty {
                Text("No results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(pickerResults) { track in
                            Button {
                                selectOverride(track, for: result)
                            } label: {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(track.title)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        if let album = track.albumTitle {
                                            Text(album)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(themeColor)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)

                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 350, height: 400)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func summaryBadge(count: Int, color: Color, label: String) -> some View {
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

    private var matchSummaryText: String? {
        let near = nearCount
        let unmatched = noMatchCount
        if near == 0 && unmatched == 0 { return nil }
        var parts: [String] = []
        if near > 0 { parts.append("\(near) near match\(near == 1 ? "" : "es")") }
        if unmatched > 0 { parts.append("\(unmatched) unmatched") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Actions

    private func runMatching() async {
        let results = await trackMatchingService.matchPlaylist(playlist.trackList, to: .appleMusic)
        matchResults = results
        selectedResultIDs = Set(results.filter { $0.confidence != .noMatch }.map { $0.id })
        phase = .review
    }

    private func openPicker(for result: TrackMatchResult) {
        pickerQuery = "\(result.originalTrack.artist) \(result.originalTrack.title)"
        pickerResults = []
        pickerTargetResultID = result.id
        searchAppleMusic()
    }

    private func searchAppleMusic() {
        let query = pickerQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        Task {
            let results = (try? await appleMusicService.search(query: query)) ?? []
            await MainActor.run {
                pickerResults = results
                isSearching = false
            }
        }
    }

    private func selectOverride(_ track: Track, for result: TrackMatchResult) {
        overrides[result.id] = track
        selectedResultIDs.insert(result.id)
        pickerTargetResultID = nil
        pickerResults = []
    }

    /// Build the M3U string and write to a temp file for sharing
    private func generateM3U() {
        var m3u = "#EXTM3U\n"
        var count = 0

        for result in matchResults where selectedResultIDs.contains(result.id) {
            let track: Track
            let originalTrack = result.originalTrack

            if let override = overrides[result.id] {
                track = override
            } else if let matched = result.matchedTrack {
                track = matched
            } else {
                continue
            }

            guard let appleMusicID = track.appleMusicID else { continue }

            let duration = Int(originalTrack.durationSeconds)
            m3u += "#EXTINF:\(duration),\(originalTrack.artist) - \(originalTrack.title)\n"
            m3u += "https://music.apple.com/song/\(appleMusicID)\n"
            count += 1
        }

        exportedCount = count

        let filename = sanitizedFilename()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(filename).m3u")
        try? m3u.write(to: tempURL, atomically: true, encoding: .utf8)
        m3uURL = tempURL

        // Update track models with Apple Music IDs
        updateTrackModels()
    }

    private func sanitizedFilename() -> String {
        playlist.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
    }

    private func updateTrackModels() {
        for result in matchResults where selectedResultIDs.contains(result.id) {
            if let override = overrides[result.id], let amID = override.appleMusicID {
                result.originalTrack.appleMusicID = amID
                result.originalTrack.matchConfidence = .exact
            } else if let matched = result.matchedTrack, let amID = matched.appleMusicID {
                result.originalTrack.appleMusicID = amID
                result.originalTrack.matchConfidence = result.confidence
            }
        }
        try? modelContext.save()
    }

    #if os(macOS)
    /// Save M3U via NSSavePanel and open in Music.app
    private func saveToDownloadsAndOpenInMusic() {
        guard let savedURL = saveViaPanel() else { return }

        // Open in Music.app
        let musicAppURL = URL(fileURLWithPath: "/System/Applications/Music.app")
        NSWorkspace.shared.open(
            [savedURL],
            withApplicationAt: musicAppURL,
            configuration: NSWorkspace.OpenConfiguration()
        )

        savedToDownloads = true
        phase = .complete
    }

    /// Save M3U via NSSavePanel only (no auto-open)
    private func saveToFile() {
        guard saveViaPanel() != nil else { return }
        savedToDownloads = true
    }

    /// Shared NSSavePanel logic — returns saved URL or nil if cancelled
    @discardableResult
    private func saveViaPanel() -> URL? {
        guard let sourceURL = m3uURL else { return nil }
        let filename = "\(sanitizedFilename()) (GrooveWire).m3u"

        let panel = NSSavePanel()
        panel.title = "Save Playlist"
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [.plainText]
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        let response = panel.runModal()
        guard response == .OK, let destURL = panel.url else { return nil }

        do {
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: destURL)
            return destURL
        } catch {
            errorMessage = error.localizedDescription
            phase = .failed
            return nil
        }
    }
    #endif
}
