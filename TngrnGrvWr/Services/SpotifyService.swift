import Foundation

@Observable
final class SpotifyService: StreamingServiceProtocol {
    let authManager: SpotifyAuthManager

    var isConnected: Bool { authManager.isAuthenticated }

    var availableDevices: [SpotifyDevice] = []
    var selectedDeviceID: String?

    private let baseURL = "https://api.spotify.com/v1"

    init(authManager: SpotifyAuthManager = SpotifyAuthManager()) {
        self.authManager = authManager
    }

    // MARK: - Profile

    func fetchProfile() async throws -> SpotifyProfile {
        let token = try await authManager.validToken()
        let url = URL(string: "\(baseURL)/me")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SpotifyError.apiError(0)
        }

        let displayName = json["display_name"] as? String
        let email = json["email"] as? String
        let spotifyID = json["id"] as? String

        var avatarURL: String?
        if let images = json["images"] as? [[String: Any]], !images.isEmpty {
            let sorted = images.sorted {
                ($0["height"] as? Int ?? 0) > ($1["height"] as? Int ?? 0)
            }
            avatarURL = sorted.first?["url"] as? String
        }

        return SpotifyProfile(
            displayName: displayName,
            email: email,
            avatarURL: avatarURL,
            spotifyID: spotifyID
        )
    }

    // MARK: - Playlists

    func fetchPlaylists() async throws -> [SpotifyPlaylist] {
        let token = try await authManager.validToken()
        var allPlaylists: [SpotifyPlaylist] = []
        var nextURL: String? = "\(baseURL)/me/playlists?limit=50"

        while let urlString = nextURL {
            let url = URL(string: urlString)!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            let plStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[SpotifyService] fetchPlaylists HTTP \(plStatus)")
            if plStatus != 200 {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("[SpotifyService] fetchPlaylists error: \(body)")
            }
            try checkResponse(response)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else { break }

            print("[SpotifyService] fetchPlaylists found \(items.count) playlists in this page")

            let playlists = items.compactMap { item -> SpotifyPlaylist? in
                guard let id = item["id"] as? String,
                      let name = item["name"] as? String else { return nil }
                let description = item["description"] as? String
                // Feb 2026 API: "tracks" renamed to "items", support both
                let trackInfo = (item["items"] as? [String: Any]) ?? (item["tracks"] as? [String: Any])
                let trackCount = trackInfo?["total"] as? Int ?? 0
                let images = item["images"] as? [[String: Any]]
                let imageURL = images?.first?["url"] as? String
                let isPublic = item["public"] as? Bool ?? false
                let owner = item["owner"] as? [String: Any]
                let ownerName = owner?["display_name"] as? String

                return SpotifyPlaylist(
                    id: id,
                    name: name,
                    description: description,
                    trackCount: trackCount,
                    imageURL: imageURL,
                    isPublic: isPublic,
                    ownerName: ownerName
                )
            }
            allPlaylists.append(contentsOf: playlists)
            nextURL = json["next"] as? String
        }

        return allPlaylists
    }

    func followPlaylist(playlistID: String) async throws {
        let token = try await authManager.validToken()
        let url = URL(string: "\(baseURL)/playlists/\(playlistID)/followers")!

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("[SpotifyService] followPlaylist HTTP \(status)")
        try checkResponse(response)
    }

    func unfollowPlaylist(playlistID: String) async throws {
        let token = try await authManager.validToken()
        let url = URL(string: "\(baseURL)/playlists/\(playlistID)/followers")!

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("[SpotifyService] unfollowPlaylist HTTP \(status)")
        try checkResponse(response)
    }

    func createPlaylist(name: String, description: String? = nil, trackIDs: [String]) async throws -> String {
        let token = try await authManager.validToken()

        // Create the playlist via POST /me/playlists
        let createURL = URL(string: "\(baseURL)/me/playlists")!
        var createRequest = URLRequest(url: createURL)
        createRequest.httpMethod = "POST"
        createRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["name": name, "public": false]
        if let description { body["description"] = description }
        createRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: createRequest)
        print("[SpotifyService] createPlaylist HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        try checkResponse(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let playlistID = json["id"] as? String else {
            throw SpotifyError.apiError(0)
        }

        // Add tracks in batches of 100 via POST /playlists/{id}/items
        let uris = trackIDs.map { "spotify:track:\($0)" }
        for batch in stride(from: 0, to: uris.count, by: 100) {
            let slice = Array(uris[batch..<min(batch + 100, uris.count)])
            let addURL = URL(string: "\(baseURL)/playlists/\(playlistID)/items")!  // Feb 2026 API
            var addRequest = URLRequest(url: addURL)
            addRequest.httpMethod = "POST"
            addRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            addRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            addRequest.httpBody = try JSONSerialization.data(withJSONObject: ["uris": slice])

            let (addData, addResponse) = try await URLSession.shared.data(for: addRequest)
            let addStatus = (addResponse as? HTTPURLResponse)?.statusCode ?? 0
            print("[SpotifyService] addTracks batch HTTP \(addStatus)")
            if addStatus != 201 {
                let body = String(data: addData, encoding: .utf8) ?? "no body"
                print("[SpotifyService] addTracks response: \(body)")
            }
            try checkResponse(addResponse, data: addData)
        }

        return playlistID
    }

    /// Extract playlist ID from a Spotify URL like https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M
    static func playlistID(from urlString: String) -> String? {
        // Handle full URLs
        if let url = URL(string: urlString),
           url.host?.contains("spotify.com") == true,
           url.pathComponents.count >= 3,
           url.pathComponents[1] == "playlist" {
            return url.pathComponents[2].components(separatedBy: "?").first
        }
        // Handle spotify:playlist:ID URIs
        if urlString.hasPrefix("spotify:playlist:") {
            return String(urlString.dropFirst("spotify:playlist:".count))
        }
        return nil
    }

    func fetchPlaylistTracks(playlistID: String) async throws -> [Track] {
        let token = try await authManager.validToken()
        var allTracks: [Track] = []
        var nextURL: String? = "\(baseURL)/playlists/\(playlistID)/items?limit=100"

        while let urlString = nextURL {
            let url = URL(string: urlString)!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            let trackStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[SpotifyService] fetchPlaylistTracks HTTP \(trackStatus) for playlist \(playlistID)")
            if trackStatus != 200 {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("[SpotifyService] fetchPlaylistTracks error: \(body)")
            }
            try checkResponse(response)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else { break }

            let tracks = items.compactMap { item -> Track? in
                // Feb 2026 API: "track" renamed to "item", support both
                let trackData = (item["item"] as? [String: Any]) ?? (item["track"] as? [String: Any])
                guard let trackData,
                      let id = trackData["id"] as? String,
                      let name = trackData["name"] as? String,
                      let durationMs = trackData["duration_ms"] as? Int,
                      let artists = trackData["artists"] as? [[String: Any]],
                      let artistName = artists.first?["name"] as? String else { return nil }

                let album = trackData["album"] as? [String: Any]
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
            allTracks.append(contentsOf: tracks)
            nextURL = json["next"] as? String
        }

        return allTracks
    }

    // MARK: - Devices

    func fetchDevices() async throws {
        let token = try await authManager.validToken()
        let url = URL(string: "\(baseURL)/me/player/devices")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = json["devices"] as? [[String: Any]] else {
            availableDevices = []
            return
        }

        availableDevices = devices.compactMap { d in
            guard let id = d["id"] as? String,
                  let name = d["name"] as? String,
                  let type = d["type"] as? String,
                  let isActive = d["is_active"] as? Bool else { return nil }
            return SpotifyDevice(id: id, name: name, type: type, isActive: isActive)
        }

        if selectedDeviceID == nil {
            selectedDeviceID = availableDevices.first(where: { $0.isActive })?.id
                ?? availableDevices.first?.id
        }
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
        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track")
        ]
        let url = components.url!
        print("🔍 [SpotifyService] Request URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        print("🔍 [SpotifyService] Token prefix: \(String(token.prefix(10)))...")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            print("🔍 [SpotifyService] Search HTTP \(http.statusCode)")
        }
        if let raw = String(data: data, encoding: .utf8) {
            print("🔍 [SpotifyService] Response (first 500): \(String(raw.prefix(500)))")
        }
        return try parseSearchResults(data)
    }

    // MARK: - Playback

    func play(track: Track) async throws {
        guard let spotifyID = track.spotifyID else {
            print("[Spotify] Track '\(track.title)' has no Spotify ID — skipping")
            return
        }

        // Auto-fetch devices if none selected
        if selectedDeviceID == nil {
            try await fetchDevices()
        }

        let token = try await authManager.validToken()

        var urlString = "\(baseURL)/me/player/play"
        if let deviceID = selectedDeviceID {
            urlString += "?device_id=\(deviceID)"
        }
        let url = URL(string: urlString)!

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["uris": ["spotify:track:\(spotifyID)"]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        // If 404 (no active device), refresh devices and retry once
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            print("[Spotify] 404 — refreshing devices and retrying")
            try await fetchDevices()
            guard selectedDeviceID != nil else {
                print("[Spotify] No devices available — open Spotify on a device first")
                throw SpotifyError.apiError(404)
            }

            // Retry with the newly selected device
            let retryURL = URL(string: "\(baseURL)/me/player/play?device_id=\(selectedDeviceID!)")!
            var retryRequest = URLRequest(url: retryURL)
            retryRequest.httpMethod = "PUT"
            retryRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            retryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            retryRequest.httpBody = request.httpBody

            let (_, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            try checkResponse(retryResponse)
            return
        }

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

    // MARK: - Recommendations

    /// Get track recommendations seeded from a single track.
    /// Returns up to `limit` tracks similar to the seed.
    func getRecommendations(seedTrackID: String, limit: Int = 25) async throws -> [Track] {
        let token = try await authManager.validToken()
        var components = URLComponents(string: "\(baseURL)/recommendations")!
        components.queryItems = [
            URLQueryItem(name: "seed_tracks", value: seedTrackID),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        let url = components.url!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("[SpotifyService] recommendations HTTP \(status)")
        try checkResponse(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tracks = json["tracks"] as? [[String: Any]] else {
            return []
        }

        return tracks.compactMap { item -> Track? in
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

    // MARK: - Transfer Playback

    func transferPlayback(to deviceID: String) async throws {
        let token = try await authManager.validToken()
        let url = URL(string: "\(baseURL)/me/player")!

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["device_ids": [deviceID], "play": false]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        try checkResponse(response)
        print("[SpotifyService] Transferred playback to device \(deviceID)")
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

    private func checkResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299, 204: return
        case 401: throw SpotifyError.unauthorized
        case 403:
            if let data, let body = String(data: data, encoding: .utf8) {
                print("[SpotifyService] 403 response body: \(body)")
            }
            throw SpotifyError.forbidden
        case 429: throw SpotifyError.rateLimited
        default:
            if let data, let body = String(data: data, encoding: .utf8) {
                print("[SpotifyService] HTTP \(http.statusCode) response body: \(body)")
            }
            throw SpotifyError.apiError(http.statusCode)
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

// MARK: - Device

struct SpotifyDevice: Identifiable {
    let id: String
    let name: String
    let type: String       // "Computer", "TV", "Speaker", "Smartphone", etc.
    let isActive: Bool

    var icon: String {
        switch type.lowercased() {
        case "computer": return "laptopcomputer"
        case "tv": return "tv"
        case "speaker": return "hifispeaker"
        case "smartphone": return "iphone"
        default: return "speaker.wave.2"
        }
    }
}

// MARK: - Playlist

struct SpotifyPlaylist: Identifiable {
    let id: String
    let name: String
    let description: String?
    let trackCount: Int
    let imageURL: String?
    let isPublic: Bool
    let ownerName: String?
}

// MARK: - Profile

struct SpotifyProfile {
    let displayName: String?
    let email: String?
    let avatarURL: String?
    let spotifyID: String?
}

// MARK: - Errors

enum SpotifyError: LocalizedError {
    case unauthorized
    case premiumRequired
    case forbidden
    case rateLimited
    case apiError(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized: "Spotify session expired. Please reconnect."
        case .premiumRequired: "Spotify Premium is required for playback control."
        case .forbidden: "Spotify denied this request (403). Check the console for details."
        case .rateLimited: "Too many requests. Please wait a moment."
        case .apiError(let code): "Spotify API error (HTTP \(code))"
        }
    }
}
