import Foundation
#if os(macOS)
import AppKit
#endif

@Observable
@MainActor
final class PlaylistLockerService {

    var lockerFiles: [LockerFile] = []
    var isBackingUp = false
    var backupProgress: String = ""

    private let fileManager = FileManager.default

    /// The iCloud Drive folder where M3U files are stored.
    var lockerURL: URL? {
        fileManager
            .url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents/Playlist Locker", isDirectory: true)
    }

    // MARK: - Scan Locker

    func scanLocker() {
        guard let url = lockerURL else {
            lockerFiles = []
            return
        }

        // Create the folder if it doesn't exist
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }

        let contents = (try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        )) ?? []

        lockerFiles = contents
            .filter { $0.pathExtension.lowercased() == "m3u" }
            .compactMap { fileURL in
                let name = fileURL.deletingPathExtension().lastPathComponent
                let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path)
                let created = attrs?[.creationDate] as? Date ?? Date()
                let size = attrs?[.size] as? Int ?? 0

                // Determine source from the M3U header
                let source = readSourceFromM3U(fileURL)

                return LockerFile(
                    url: fileURL,
                    name: name,
                    source: source,
                    createdAt: created,
                    fileSize: size
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Backup Apple Music

    func backupAppleMusic(service: AppleMusicService) async throws {
        isBackingUp = true
        defer { isBackingUp = false }

        backupProgress = "Fetching Apple Music playlists…"
        let playlists = try await service.fetchPlaylists()

        for (index, playlist) in playlists.enumerated() {
            backupProgress = "Backing up \(index + 1)/\(playlists.count): \(playlist.name)"
            let tracks = try await service.fetchPlaylistTracks(playlistID: playlist.id)
            let m3uContent = buildM3U(
                playlistName: playlist.name,
                source: .appleMusic,
                tracks: tracks
            )
            try writeM3U(name: playlist.name, source: .appleMusic, content: m3uContent)
        }

        backupProgress = "Done — \(playlists.count) playlists backed up"
        scanLocker()
    }

    // MARK: - Backup Spotify

    func backupSpotify(service: SpotifyService) async throws {
        isBackingUp = true
        defer { isBackingUp = false }

        backupProgress = "Fetching Spotify playlists…"
        let playlists = try await service.fetchPlaylists()

        for (index, playlist) in playlists.enumerated() {
            backupProgress = "Backing up \(index + 1)/\(playlists.count): \(playlist.name)"
            let tracks = try await service.fetchPlaylistTracks(playlistID: playlist.id)
            let m3uContent = buildM3U(
                playlistName: playlist.name,
                source: .spotify,
                tracks: tracks
            )
            try writeM3U(name: playlist.name, source: .spotify, content: m3uContent)
        }

        backupProgress = "Done — \(playlists.count) playlists backed up"
        scanLocker()
    }

    // MARK: - Delete

    func deleteFile(_ file: LockerFile) {
        try? fileManager.removeItem(at: file.url)
        scanLocker()
    }

    // MARK: - M3U Builder

    private func buildM3U(playlistName: String, source: StreamingService, tracks: [Track]) -> String {
        var lines: [String] = []
        lines.append("#EXTM3U")
        lines.append("#PLAYLIST:\(playlistName)")
        lines.append("#EXTSOURCE:\(source.rawValue)")
        lines.append("")

        for track in tracks {
            let duration = Int(track.durationSeconds)
            lines.append("#EXTINF:\(duration),\(track.artist) - \(track.title)")

            if let album = track.albumTitle {
                lines.append("#EXTALB:\(album)")
            }
            if let appleID = track.appleMusicID {
                lines.append("#EXT-APPLE-ID:\(appleID)")
            }
            if let spotifyID = track.spotifyID {
                lines.append("#EXT-SPOTIFY-ID:\(spotifyID)")
            }
            // M3U requires a path/URI line after each EXTINF
            if let spotifyID = track.spotifyID {
                lines.append("spotify:track:\(spotifyID)")
            } else if let appleID = track.appleMusicID {
                lines.append("apple-music:track:\(appleID)")
            } else {
                lines.append("\(track.artist) - \(track.title)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - File I/O

    private func writeM3U(name: String, source: StreamingService, content: String) throws {
        guard let lockerURL else {
            throw LockerError.noiCloud
        }

        if !fileManager.fileExists(atPath: lockerURL.path) {
            try fileManager.createDirectory(at: lockerURL, withIntermediateDirectories: true)
        }

        // Sanitize filename
        let safeName = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let fileURL = lockerURL.appendingPathComponent("\(safeName).m3u")

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // Stamp custom icon on macOS
        #if os(macOS)
        stampIcon(on: fileURL, source: source)
        #endif
    }

    #if os(macOS)
    private func stampIcon(on fileURL: URL, source: StreamingService) {
        let imageName: String
        switch source {
        case .spotify: imageName = "LockerIconSpotify"
        case .appleMusic: imageName = "LockerIconAppleMusic"
        case .none: imageName = "AppIcon"
        }

        guard let image = NSImage(named: imageName) else { return }
        NSWorkspace.shared.setIcon(image, forFile: fileURL.path, options: [])
    }
    #endif

    // MARK: - Helpers

    private func readSourceFromM3U(_ url: URL) -> StreamingService {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return .none }
        let lines = content.components(separatedBy: .newlines)
        for line in lines.prefix(5) {
            if line.hasPrefix("#EXTSOURCE:") {
                let raw = String(line.dropFirst("#EXTSOURCE:".count))
                return StreamingService(rawValue: raw) ?? .none
            }
        }
        // Infer from track URIs
        if content.contains("spotify:track:") { return .spotify }
        if content.contains("apple-music:track:") { return .appleMusic }
        return .none
    }
}

// MARK: - LockerFile

struct LockerFile: Identifiable {
    let url: URL
    let name: String
    let source: StreamingService
    let createdAt: Date
    let fileSize: Int

    var id: URL { url }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}

// MARK: - Errors

enum LockerError: LocalizedError {
    case noiCloud

    var errorDescription: String? {
        switch self {
        case .noiCloud: "iCloud Drive is not available. Sign into iCloud in System Settings."
        }
    }
}
