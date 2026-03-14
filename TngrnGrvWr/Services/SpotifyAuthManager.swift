import Foundation
import AuthenticationServices
import CryptoKit

@Observable
final class SpotifyAuthManager {
    // MARK: - Configuration
    // TODO: Replace with your Spotify app's Client ID from https://developer.spotify.com/dashboard
    static let clientID = "db88d9b2c75340f7a5fd84398bef8afb"
    static let redirectURI = "tngrnGrvWr://spotify-callback"
    static let scopes = [
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-currently-playing",
        "user-read-email",
        "playlist-modify-public",
        "playlist-modify-private"
    ].joined(separator: " ")

    // MARK: - State
    var isAuthenticated: Bool { accessToken != nil }
    private(set) var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiration: Date?
    private var codeVerifier: String?

    // MARK: - Keychain Keys
    private let accessTokenKey = "com.TangerineGrooveWire.spotify.accessToken"
    private let refreshTokenKey = "com.TangerineGrooveWire.spotify.refreshToken"
    private let expirationKey = "com.TangerineGrooveWire.spotify.expiration"

    init() {
        loadTokens()
    }

    // MARK: - PKCE

    func generateAuthURL() -> URL {
        let verifier = generateCodeVerifier()
        codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge)
        ]
        return components.url!
    }

    func handleCallback(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let verifier = codeVerifier else {
            throw SpotifyAuthError.invalidCallback
        }
        try await exchangeCode(code, verifier: verifier)
    }

    func disconnect() {
        accessToken = nil
        refreshToken = nil
        tokenExpiration = nil
        deleteFromKeychain(key: accessTokenKey)
        deleteFromKeychain(key: refreshTokenKey)
        deleteFromKeychain(key: expirationKey)
    }

    func validToken() async throws -> String {
        if let token = accessToken, let expiration = tokenExpiration, expiration > Date() {
            return token
        }
        guard let refresh = refreshToken else {
            throw SpotifyAuthError.notAuthenticated
        }
        try await refreshAccessToken(refresh)
        guard let token = accessToken else {
            throw SpotifyAuthError.tokenRefreshFailed
        }
        return token
    }

    // MARK: - Token Exchange

    private func exchangeCode(_ code: String, verifier: String) async throws {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": Self.redirectURI,
            "client_id": Self.clientID,
            "code_verifier": verifier
        ]
        request.httpBody = body.urlEncodedData

        let (data, _) = try await URLSession.shared.data(for: request)
        try parseTokenResponse(data)
    }

    private func refreshAccessToken(_ refresh: String) async throws {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refresh,
            "client_id": Self.clientID
        ]
        request.httpBody = body.urlEncodedData

        let (data, _) = try await URLSession.shared.data(for: request)
        try parseTokenResponse(data)
    }

    private func parseTokenResponse(_ data: Data) throws {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["access_token"] as? String,
              let expiresIn = json?["expires_in"] as? Int else {
            throw SpotifyAuthError.invalidTokenResponse
        }

        accessToken = token
        tokenExpiration = Date().addingTimeInterval(TimeInterval(expiresIn))

        if let refresh = json?["refresh_token"] as? String {
            refreshToken = refresh
        }

        saveTokens()
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncoded
    }

    // MARK: - Keychain

    private func saveTokens() {
        if let token = accessToken {
            saveToKeychain(key: accessTokenKey, value: token)
        }
        if let refresh = refreshToken {
            saveToKeychain(key: refreshTokenKey, value: refresh)
        }
        if let expiration = tokenExpiration {
            saveToKeychain(key: expirationKey, value: String(expiration.timeIntervalSince1970))
        }
    }

    private func loadTokens() {
        accessToken = loadFromKeychain(key: accessTokenKey)
        refreshToken = loadFromKeychain(key: refreshTokenKey)
        if let expirationString = loadFromKeychain(key: expirationKey),
           let interval = Double(expirationString) {
            tokenExpiration = Date(timeIntervalSince1970: interval)
        }
    }

    private func saveToKeychain(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum SpotifyAuthError: LocalizedError {
    case invalidCallback
    case notAuthenticated
    case tokenRefreshFailed
    case invalidTokenResponse

    var errorDescription: String? {
        switch self {
        case .invalidCallback: "Invalid Spotify callback URL"
        case .notAuthenticated: "Not authenticated with Spotify"
        case .tokenRefreshFailed: "Failed to refresh Spotify token"
        case .invalidTokenResponse: "Invalid token response from Spotify"
        }
    }
}

// MARK: - Helpers

private extension Dictionary where Key == String, Value == String {
    var urlEncodedData: Data {
        map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)!
    }
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
