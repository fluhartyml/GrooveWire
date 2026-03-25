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
    @State private var themeManager = ThemeManager()
    @State private var pendingBridgeID: UUID?

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            User.self,
            Bridge.self,
            Track.self,
            Message.self,
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
                .environment(themeManager)
                .environment(\.themeColor, themeManager.accentColor)
                .tint(themeManager.accentColor)
                .onAppear {
                    if playbackManager == nil {
                        playbackManager = PlaybackManager(spotifyService: spotifyService, appleMusicService: appleMusicService)
                    }
                    if trackMatchingService == nil {
                        trackMatchingService = TrackMatchingService(spotifyService: spotifyService, appleMusicService: appleMusicService)
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        #if os(macOS)
        .defaultSize(width: 700, height: 650)
        #endif
        .modelContainer(sharedModelContainer)
    }

    private func handleDeepLink(_ url: URL) {
        // tngrnGrvWr://bridge/<UUID>
        guard url.scheme == "tngrnGrvWr",
              url.host == "bridge",
              let idString = url.pathComponents.last,
              let bridgeID = UUID(uuidString: idString) else { return }
        pendingBridgeID = bridgeID
        print("[DeepLink] Received invite for bridge: \(bridgeID)")
    }
}
