import Foundation
import Observation
import os

private let matchLogger = Logger(subsystem: "com.TangerineGrooveWire.TngrnGrvWr", category: "TrackMatch")

/// Log match operations via os.Logger (no temp file writes)
private func debugLog(_ message: String) {
    matchLogger.info("\(message)")
}

// MARK: - Match Confidence

enum MatchConfidence: String, Codable, Comparable {
    case exact       // title + artist match perfectly (case-insensitive)
    case near        // close match (remix, live, remaster, slight title difference)
    case noMatch     // couldn't find it on the other service

    private var sortOrder: Int {
        switch self {
        case .exact: return 0
        case .near: return 1
        case .noMatch: return 2
        }
    }

    static func < (lhs: MatchConfidence, rhs: MatchConfidence) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Match Result

struct TrackMatchResult: Identifiable {
    let id = UUID()
    let originalTrack: Track
    let matchedTrack: Track?
    let confidence: MatchConfidence
    let targetService: StreamingService
}

// MARK: - Track Matching Service

@MainActor
@Observable
final class TrackMatchingService {
    private let spotifyService: SpotifyService
    private let appleMusicService: AppleMusicService

    var isMatching = false
    var matchProgress: Double = 0  // 0.0 - 1.0 for batch operations

    init(spotifyService: SpotifyService, appleMusicService: AppleMusicService) {
        self.spotifyService = spotifyService
        self.appleMusicService = appleMusicService
    }

    // MARK: - Single Track Matching

    /// Find the equivalent of a track on the other service.
    /// If the track has a Spotify ID but no Apple Music ID, search Apple Music (and vice versa).
    func findMatch(for track: Track, on targetService: StreamingService) async -> TrackMatchResult {
        let query = "\(track.artist) \(track.title)"
        debugLog("Searching \(targetService.displayName) for: \(query)")

        do {
            let results: [Track]
            switch targetService {
            case .spotify:
                guard spotifyService.isConnected else {
                    debugLog("Spotify not connected — skipping")
                    return TrackMatchResult(originalTrack: track, matchedTrack: nil, confidence: .noMatch, targetService: targetService)
                }
                results = try await spotifyService.search(query: query)
            case .appleMusic:
                guard appleMusicService.isConnected else {
                    debugLog("Apple Music not connected — skipping")
                    return TrackMatchResult(originalTrack: track, matchedTrack: nil, confidence: .noMatch, targetService: targetService)
                }
                results = try await appleMusicService.search(query: query)
            case .none:
                return TrackMatchResult(originalTrack: track, matchedTrack: nil, confidence: .noMatch, targetService: targetService)
            }

            debugLog("Got \(results.count) results for: \(query)")

            // Score each result against the original
            let scored = results.map { candidate -> (Track, MatchConfidence) in
                let confidence = scoreMatch(original: track, candidate: candidate)
                return (candidate, confidence)
            }

            // Pick the best match
            if let best = scored.sorted(by: { $0.1 < $1.1 }).first, best.1 != .noMatch {
                debugLog("Found \(best.1.rawValue) match: \(best.0.title) by \(best.0.artist)")
                return TrackMatchResult(originalTrack: track, matchedTrack: best.0, confidence: best.1, targetService: targetService)
            }

            debugLog("No match found for: \(track.title) by \(track.artist)")
            return TrackMatchResult(originalTrack: track, matchedTrack: nil, confidence: .noMatch, targetService: targetService)

        } catch {
            debugLog("Search FAILED for \(track.title): \(error.localizedDescription)")
            return TrackMatchResult(originalTrack: track, matchedTrack: nil, confidence: .noMatch, targetService: targetService)
        }
    }

    // MARK: - Enrich Track

    /// Fill in the missing service ID on a track. If it has a Spotify ID but no Apple Music ID,
    /// search Apple Music and populate it (and vice versa).
    func enrichTrack(_ track: Track) async -> MatchConfidence {
        if track.spotifyID != nil && track.appleMusicID == nil && appleMusicService.isConnected {
            let result = await findMatch(for: track, on: .appleMusic)
            if let match = result.matchedTrack {
                track.appleMusicID = match.appleMusicID
                return result.confidence
            }
            return .noMatch
        }

        if track.appleMusicID != nil && track.spotifyID == nil && spotifyService.isConnected {
            let result = await findMatch(for: track, on: .spotify)
            if let match = result.matchedTrack {
                track.spotifyID = match.spotifyID
                return result.confidence
            }
            return .noMatch
        }

        // Already has both IDs
        if track.spotifyID != nil && track.appleMusicID != nil {
            return .exact
        }

        return .noMatch
    }

    // MARK: - Batch Matching (Playlist Transfer)

    /// Match an entire playlist's worth of tracks against the target service.
    func matchPlaylist(_ tracks: [Track], to targetService: StreamingService) async -> [TrackMatchResult] {
        guard !tracks.isEmpty else { return [] }

        isMatching = true
        matchProgress = 0
        var results: [TrackMatchResult] = []

        for (index, track) in tracks.enumerated() {
            let result = await findMatch(for: track, on: targetService)
            results.append(result)
            matchProgress = Double(index + 1) / Double(tracks.count)

            // Delay between requests to avoid Spotify rate limiting
            if index < tracks.count - 1 {
                try? await Task.sleep(for: .milliseconds(500))
            }
        }

        isMatching = false
        matchProgress = 1.0

        let exact = results.filter { $0.confidence == .exact }.count
        let near = results.filter { $0.confidence == .near }.count
        let noMatch = results.filter { $0.confidence == .noMatch }.count
        print("[TrackMatch] Playlist match complete: \(exact) exact, \(near) near, \(noMatch) no match out of \(tracks.count) tracks")

        return results
    }

    // MARK: - Dual Search

    /// Search both services in parallel and merge results, deduplicating by title+artist.
    func searchBothServices(query: String) async -> [Track] {
        let spotifyConnected = spotifyService.isConnected
        let appleMusicConnected = appleMusicService.isConnected

        async let spotifyResults: [Track] = {
            guard spotifyConnected else { return [] }
            return (try? await spotifyService.search(query: query)) ?? []
        }()

        async let appleMusicResults: [Track] = {
            guard appleMusicConnected else { return [] }
            return (try? await appleMusicService.search(query: query)) ?? []
        }()

        let spotify = await spotifyResults
        let appleMusic = await appleMusicResults

        return mergeResults(spotify: spotify, appleMusic: appleMusic)
    }

    // MARK: - Matching Logic

    private func scoreMatch(original: Track, candidate: Track) -> MatchConfidence {
        let origTitle = normalize(original.title)
        let origArtist = normalize(original.artist)
        let candTitle = normalize(candidate.title)
        let candArtist = normalize(candidate.artist)

        // Exact: title and artist match perfectly after normalization
        if origTitle == candTitle && origArtist == candArtist {
            return .exact
        }

        // Near: title contains the other (handles "Song Title - Remastered" vs "Song Title")
        // and artist matches
        let titleClose = origTitle.contains(candTitle) || candTitle.contains(origTitle)
        let artistClose = origArtist.contains(candArtist) || candArtist.contains(origArtist)

        if titleClose && artistClose {
            return .near
        }

        // Near: exact artist, very similar title (Levenshtein-ish check)
        if artistClose && similarity(origTitle, candTitle) > 0.8 {
            return .near
        }

        return .noMatch
    }

    /// Normalize a string for comparison: lowercase, strip common suffixes, trim whitespace.
    private func normalize(_ string: String) -> String {
        var s = string.lowercased()
            .trimmingCharacters(in: .whitespaces)

        // Strip common version suffixes
        let suffixes = [
            " - remastered", " - remaster", " (remastered)", " (remaster)",
            " - deluxe", " (deluxe)", " - deluxe edition", " (deluxe edition)",
            " - single", " (single)", " - radio edit", " (radio edit)",
            " - explicit", " (explicit)", " - clean", " (clean)",
            " - live", " (live)", " - acoustic", " (acoustic)",
            " - bonus track", " (bonus track)", " - feat.", " (feat.",
        ]
        for suffix in suffixes {
            if s.hasSuffix(suffix) {
                s = String(s.dropLast(suffix.count))
            }
        }

        // Strip "feat." and everything after it for parenthetical features
        if let featRange = s.range(of: " (feat.") {
            s = String(s[s.startIndex..<featRange.lowerBound])
        }

        return s.trimmingCharacters(in: .whitespaces)
    }

    /// Simple similarity ratio between two strings (0.0 - 1.0).
    private func similarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1.0 }
        if a.isEmpty || b.isEmpty { return 0.0 }

        let longer = a.count >= b.count ? a : b
        let shorter = a.count >= b.count ? b : a

        let longerLength = Double(longer.count)
        let distance = Double(levenshteinDistance(longer, shorter))

        return (longerLength - distance) / longerLength
    }

    /// Levenshtein edit distance.
    private func levenshteinDistance(_ s: String, _ t: String) -> Int {
        let sArray = Array(s)
        let tArray = Array(t)
        let sCount = sArray.count
        let tCount = tArray.count

        if sCount == 0 { return tCount }
        if tCount == 0 { return sCount }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: tCount + 1), count: sCount + 1)

        for i in 0...sCount { matrix[i][0] = i }
        for j in 0...tCount { matrix[0][j] = j }

        for i in 1...sCount {
            for j in 1...tCount {
                let cost = sArray[i - 1] == tArray[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,       // deletion
                    matrix[i][j - 1] + 1,        // insertion
                    matrix[i - 1][j - 1] + cost  // substitution
                )
            }
        }

        return matrix[sCount][tCount]
    }

    // MARK: - Merge / Dedup

    /// Merge Spotify and Apple Music search results, combining tracks that are the same song.
    private func mergeResults(spotify: [Track], appleMusic: [Track]) -> [Track] {
        var merged: [Track] = []
        var usedAppleMusicIndices = Set<Int>()

        for spotifyTrack in spotify {
            var bestMatchIndex: Int?
            var bestConfidence: MatchConfidence = .noMatch

            for (i, amTrack) in appleMusic.enumerated() where !usedAppleMusicIndices.contains(i) {
                let confidence = scoreMatch(original: spotifyTrack, candidate: amTrack)
                if confidence < bestConfidence {
                    bestConfidence = confidence
                    bestMatchIndex = i
                }
            }

            if let matchIndex = bestMatchIndex, bestConfidence != .noMatch {
                // Merge: Spotify track gets Apple Music ID
                let amTrack = appleMusic[matchIndex]
                spotifyTrack.appleMusicID = amTrack.appleMusicID
                usedAppleMusicIndices.insert(matchIndex)
                print("[TrackMatch] Merged: \(spotifyTrack.title) — both services")
            }

            merged.append(spotifyTrack)
        }

        // Add remaining Apple Music tracks that didn't match any Spotify track
        for (i, amTrack) in appleMusic.enumerated() where !usedAppleMusicIndices.contains(i) {
            merged.append(amTrack)
        }

        return merged
    }
}
