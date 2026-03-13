import Foundation

@MainActor
protocol StreamingServiceProtocol: Observable {
    var isConnected: Bool { get }
    func connect() async throws
    func disconnect()
    func search(query: String) async throws -> [Track]
    func play(track: Track) async throws
    func pause() async throws
    func resume() async throws
    func seek(to seconds: Double) async throws
    func currentPlaybackPosition() async -> Double?
}
