import Foundation
import Observation

@MainActor
@Observable
final class PlaybackManager {
    var currentTrack: Track?
    var isPlaying = false
    var queue: [Track] = []
    var currentIndex = 0
    var skippedMessage: String?

    private let spotifyService: SpotifyService
    private let appleMusicService: AppleMusicService
    private var pollTimer: Timer?

    init(spotifyService: SpotifyService, appleMusicService: AppleMusicService) {
        self.spotifyService = spotifyService
        self.appleMusicService = appleMusicService
    }

    // MARK: - Playback

    func play(track: Track, from trackList: [Track]? = nil) {
        if let trackList {
            if queue.isEmpty || queue.map({ $0.id }) != trackList.map({ $0.id }) {
                // First time or different track list — load the queue
                queue = trackList
            }
            // Jump to the tapped track within the existing queue
            currentIndex = queue.firstIndex(where: { $0.id == track.id }) ?? 0
        }
        currentTrack = track
        isPlaying = true
        startPolling()

        Task {
            await playCurrentTrack()
        }
    }

    func togglePlayback() {
        guard currentTrack != nil else { return }
        Task {
            do {
                if isPlaying {
                    try await activeService?.pause()
                    stopPolling()
                } else {
                    if let track = currentTrack {
                        try await activeService?.play(track: track)
                    }
                    startPolling()
                }
                isPlaying.toggle()
            } catch {
                print("[PlaybackManager] Toggle failed: \(error.localizedDescription)")
            }
        }
    }

    func pause() {
        Task {
            try? await activeService?.pause()
            isPlaying = false
            stopPolling()
        }
    }

    func resume() {
        guard let track = currentTrack else { return }
        Task {
            do {
                try await activeService?.play(track: track)
                isPlaying = true
                startPolling()
            } catch {
                print("[PlaybackManager] Resume failed: \(error.localizedDescription)")
            }
        }
    }

    func skipForward() {
        guard !queue.isEmpty, currentIndex < queue.count - 1 else { return }
        currentIndex += 1
        let track = queue[currentIndex]
        currentTrack = track
        if isPlaying {
            Task {
                try? await activeService?.play(track: track)
            }
        }
    }

    func skipBackward() {
        guard !queue.isEmpty, currentIndex > 0 else { return }
        currentIndex -= 1
        let track = queue[currentIndex]
        currentTrack = track
        if isPlaying {
            Task {
                try? await activeService?.play(track: track)
            }
        }
    }

    var nextTrack: Track? {
        guard !queue.isEmpty, currentIndex + 1 < queue.count else { return nil }
        return queue[currentIndex + 1]
    }

    var canSkipForward: Bool {
        !queue.isEmpty && currentIndex < queue.count - 1
    }

    var canSkipBackward: Bool {
        !queue.isEmpty && currentIndex > 0
    }

    // MARK: - Play with Skip Handling

    private func playCurrentTrack() async {
        guard let track = currentTrack, let service = activeService else {
            print("[PlaybackManager] No active service — cannot play")
            isPlaying = false
            stopPolling()
            return
        }

        do {
            print("[PlaybackManager] Playing '\(track.title)' via \(service is SpotifyService ? "Spotify" : "Apple Music")")
            try await service.play(track: track)
            print("[PlaybackManager] Play command sent successfully")
            skippedMessage = nil
        } catch is SpotifySkipError {
            // Show skip message and auto-advance
            skippedMessage = "Apple Music only, skipped"
            print("[PlaybackManager] Skipped '\(track.title)' — no Spotify ID")

            // Clear message after 2 seconds
            Task {
                try? await Task.sleep(for: .seconds(2))
                if skippedMessage != nil { skippedMessage = nil }
            }

            // Auto-advance to next track
            if canSkipForward {
                currentIndex += 1
                currentTrack = queue[currentIndex]
                await playCurrentTrack()
            } else {
                isPlaying = false
                stopPolling()
            }
        } catch {
            print("[PlaybackManager] Play failed: \(error.localizedDescription)")
            isPlaying = false
            stopPolling()
        }
    }

    // MARK: - Auto-Advance Polling

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPlaybackProgress()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func checkPlaybackProgress() {
        guard let track = currentTrack, isPlaying, track.durationSeconds > 0 else { return }

        Task {
            guard let position = await activeService?.currentPlaybackPosition() else { return }

            // If we're within 2 seconds of the end, advance to the next track
            if position >= track.durationSeconds - 2 {
                if canSkipForward {
                    print("[PlaybackManager] Track ended, advancing to next")
                    skipForward()
                } else if !queue.isEmpty {
                    // Wrap to beginning of queue
                    print("[PlaybackManager] Queue wrapped to beginning")
                    currentIndex = 0
                    let nextTrack = queue[0]
                    currentTrack = nextTrack
                    Task { try? await activeService?.play(track: nextTrack) }
                } else {
                    // No queue at all
                    print("[PlaybackManager] Queue finished")
                    isPlaying = false
                    stopPolling()
                }
            }
        }
    }

    // MARK: - Service Routing

    private var activeService: (any StreamingServiceProtocol)? {
        if spotifyService.isConnected { return spotifyService }
        if appleMusicService.isConnected { return appleMusicService }
        return nil
    }

    var hasActiveService: Bool {
        spotifyService.isConnected || appleMusicService.isConnected
    }

    var isSpotifyActive: Bool { spotifyService.isConnected }
    var isAppleMusicActive: Bool { appleMusicService.isConnected }
}
