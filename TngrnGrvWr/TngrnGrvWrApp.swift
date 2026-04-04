//
//  TngrnGrvWrApp.swift
//  TngrnGrvWr
//
//  Created by Michael Fluharty on 3/13/26.
//

import SwiftUI
import SwiftData

@main
struct TngrnGrvWrApp: App {
    @State private var spotifyService = SpotifyService()
    @State private var appleMusicService = AppleMusicService()
    @State private var playbackManager: PlaybackManager?
    @State private var trackMatchingService: TrackMatchingService?
    @State private var playlistLockerService = PlaylistLockerService()

    private let accentColor = Color(red: 1.0, green: 0.52, blue: 0.0) // Tangerine

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Track.self,
            SavedPlaylist.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(spotifyService)
                .environment(appleMusicService)
                .environment(playbackManager ?? PlaybackManager(spotifyService: spotifyService, appleMusicService: appleMusicService))
                .environment(trackMatchingService ?? TrackMatchingService(spotifyService: spotifyService, appleMusicService: appleMusicService))
                .environment(playlistLockerService)
                .environment(\.themeColor, accentColor)
                .tint(accentColor)
                .onAppear {
                    if playbackManager == nil {
                        playbackManager = PlaybackManager(spotifyService: spotifyService, appleMusicService: appleMusicService)
                    }
                    if trackMatchingService == nil {
                        trackMatchingService = TrackMatchingService(spotifyService: spotifyService, appleMusicService: appleMusicService)
                    }
                }
        }
        #if os(macOS)
        .defaultSize(width: 700, height: 650)
        #endif
        .modelContainer(sharedModelContainer)
    }
}
