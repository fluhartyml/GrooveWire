import Foundation

@Observable
final class SpotifyService: StreamingServiceProtocol {
    let authManager: SpotifyAuthManager

    var isConnected: Bool { authManager.isAuthenticated }

    private let baseURL = "https://api.spotify.com/v1"

    init(authManager: SpotifyAuthManager = SpotifyAuthManager()) {
        self.authManager = authManager
    }

    // MARK: - Auth

    func connect() async throws {
        // Auth is handled via SpotifyLoginView + SpotifyAuthManager
        // This is a no-op; the view triggers the OAuth flow
    }

    func disconnect() {
        authManager.disconnect()
    }

    // MARK: - Search

    func search(query: String) async throws -> [Track] {
        let token = try await authManager.validToken()
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(baseURL)/search?q=\(encoded)&type=track&limit=20")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try parseSearchResults(data)
    }

    // MARK: - Playback

    func play(track: Track) async throws {
        guard let spotifyID = track.spotifyID else { return }
        let token = try await authManager.validToken()
        let url = URL(string: "\(baseURL)/me/player/play")!

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["uris": ["spotify:track:\(spotifyID)"]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
    }

    func pause() async throws {
        try await playerRequest(endpoint: "/me/player/pause", method: "PUT")
    }

    func resume() async throws {
        try await playerRequest(endpoint: "/me/player/play", method: "PUT")
    }

    func seek(to seconds: Double) async throws {
        let ms = Int(seconds * 1000)
        try await playerRequest(endpoint: "/me/player/seek?position_ms=\(ms)", method: "PUT")
    }

    func addToQueue(track: Track) async throws {
        guard let spotifyID = track.spotifyID else { return }
        let uri = "spotify:track:\(spotifyID)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        try await playerRequest(endpoint: "/me/player/queue?uri=\(uri)", method: "POST")
    }

    func currentPlaybackPosition() async -> Double? {
        guard let token = try? await authManager.validToken() else { return nil }
        let url = URL(string: "\(baseURL)/me/player")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let progressMs = json["progress_ms"] as? Int else {
            return nil
        }
        return Double(progressMs) / 1000.0
    }

    // MARK: - Helpers

    private func playerRequest(endpoint: String, method: String) async throws {
        let token = try await authManager.validToken()
        let url = URL(string: "\(baseURL)\(endpoint)")!

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
    }

    private func checkResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299, 204: return
        case 401: throw SpotifyError.unauthorized
        case 403: throw SpotifyError.premiumRequired
        case 429: throw SpotifyError.rateLimited
        default: throw SpotifyError.apiError(http.statusCode)
        }
    }

    private func parseSearchResults(_ data: Data) throws -> [Track] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tracks = json["tracks"] as? [String: Any],
              let items = tracks["items"] as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> Track? in
            guard let id = item["id"] as? String,
                  let name = item["name"] as? String,
                  let durationMs = item["duration_ms"] as? Int,
                  let artists = item["artists"] as? [[String: Any]],
                  let artistName = artists.first?["name"] as? String else {
                return nil
            }

            let album = item["album"] as? [String: Any]
            let albumName = album?["name"] as? String
            let images = album?["images"] as? [[String: Any]]
            let artworkURL = images?.first?["url"] as? String

            return Track(
                title: name,
                artist: artistName,
                albumTitle: albumName,
                artworkURL: artworkURL,
                spotifyID: id,
                durationSeconds: Double(durationMs) / 1000.0,
                addedBy: UUID()
            )
        }
    }
}

// MARK: - Errors

enum SpotifyError: LocalizedError {
    case unauthorized
    case premiumRequired
    case rateLimited
    case apiError(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized: "Spotify session expired. Please reconnect."
        case .premiumRequired: "Spotify Premium is required for playback control."
        case .rateLimited: "Too many requests. Please wait a moment."
        case .apiError(let code): "Spotify API error (HTTP \(code))"
        }
    }
}
