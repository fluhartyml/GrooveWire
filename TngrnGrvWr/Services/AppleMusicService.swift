import Foundation
import MusicKit

@Observable
final class AppleMusicService: StreamingServiceProtocol {
    var isConnected: Bool { authorizationStatus == .authorized }
    var hasSubscription: Bool = false
    private var authorizationStatus: MusicAuthorization.Status = .notDetermined
    private let player = ApplicationMusicPlayer.shared

    init() {
        authorizationStatus = MusicAuthorization.currentStatus
    }

    // MARK: - Auth

    func connect() async throws {
        let status = await MusicAuthorization.request()
        await MainActor.run { authorizationStatus = status }
        if status != .authorized {
            throw AppleMusicError.notAuthorized
        }
        await checkSubscription()
    }

    func checkSubscription() async {
        do {
            let subscription = try await MusicSubscription.current
            await MainActor.run {
                hasSubscription = subscription.canPlayCatalogContent
            }
        } catch {
            print("[AppleMusic] Subscription check failed: \(error.localizedDescription)")
        }
    }

    func disconnect() {
        authorizationStatus = .notDetermined
    }

    // MARK: - Search

    func search(query: String) async throws -> [Track] {
        var request = MusicCatalogSearchRequest(term: query, types: [Song.self])
        request.limit = 20
        let response = try await request.response()

        return response.songs.map { song in
            Track(
                title: song.title,
                artist: song.artistName,
                albumTitle: song.albumTitle,
                artworkURL: song.artwork?.url(width: 300, height: 300)?.absoluteString,
                appleMusicID: song.id.rawValue,
                durationSeconds: song.duration ?? 0,
                addedBy: UUID()
            )
        }
    }

    // MARK: - Playlist Creation

    func createPlaylist(name: String, description: String? = nil, trackIDs: [String]) async throws -> String {
        #if os(iOS)
        let library = MusicLibrary.shared

        // Resolve each Apple Music ID into a Song object
        var songs: [Song] = []
        for trackID in trackIDs {
            let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(trackID))
            let response = try await request.response()
            if let song = response.items.first {
                songs.append(song)
            }
        }

        guard !songs.isEmpty else {
            throw AppleMusicError.noTracksToAdd
        }

        let playlist = try await library.createPlaylist(
            name: name,
            description: description,
            items: songs
        )

        print("[AppleMusic] Created playlist '\(name)' with \(songs.count) tracks")
        return playlist.id.rawValue
        #else
        throw AppleMusicError.notAvailableOnMac
        #endif
    }

    // MARK: - Playback

    func play(track: Track) async throws {
        guard let musicID = track.appleMusicID else { return }
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(musicID))
        let response = try await request.response()
        guard let song = response.items.first else { return }

        player.queue = [song]
        try await player.play()
    }

    func pause() async throws {
        player.pause()
    }

    func resume() async throws {
        try await player.play()
    }

    func seek(to seconds: Double) async throws {
        player.playbackTime = seconds
    }

    func currentPlaybackPosition() async -> Double? {
        player.playbackTime
    }
}

// MARK: - Errors

enum AppleMusicError: LocalizedError {
    case notAuthorized
    case noTracksToAdd
    case notAvailableOnMac

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "Apple Music access was not authorized."
        case .noTracksToAdd: "No tracks could be resolved for the playlist."
        case .notAvailableOnMac: "Apple Music playlist creation is only available on iOS."
        }
    }
}
