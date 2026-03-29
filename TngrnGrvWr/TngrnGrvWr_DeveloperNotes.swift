//
//  TngrnGrvWr_DeveloperNotes.swift
//  TngrnGrvWr (Tangerine GrooveWire)
//
//  Developer Notes — Persistent Memory for AI Assistants
//  Created: 2026 MAR 18 (Claude Code)
//

// ============================================================================
// MARK: - PROJECT IDENTITY
// ============================================================================
//
//  Name:           Tangerine GrooveWire
//  Short Name:     TBD (TGW abbreviation is crowded)
//  Product Name:   TngrnGrvWr
//  Bundle ID:      com.TangerineGrooveWire.TngrnGrvWr
//  Org Identifier: com.TangerineGrooveWire
//  Platform:       iOS / macOS (Universal)
//  Version:        1.0
//  Language:       Swift 6.2, SwiftUI
//  Storage:        SwiftData + CloudKit
//  Deployment:     iOS 18.6 / macOS 15.6
//  GitHub:         fluhartyml/GrooveWire
//  Location:       /Users/michaelfluharty/Developer/TngrnGrvWr/

// ============================================================================
// MARK: - DESCRIPTION
// ============================================================================
//
//  Playlist curation and cross-service transfer tool.
//  "Apple Music and Spotify, Streaming services; GrooveWire, Bridging the gap."
//  Core concept: playlists as trading cards — shareable, portable, cross-service.
//  "Bridge" = bridging streaming services, platforms, and users.
//  Winamp/LimeWire-era nostalgia: browse someone's playlists like a shared drive,
//  queue songs for "download" (match metadata to your own streaming service).
//  100% legal — only names and metadata are shared, not physical media.
//  Social grows organically through external channels (iMessage, AirDrop,
//  sneakernet) — no in-app messaging or DMs by design.
//  Feeds Michael's app ecosystem: CryoTunes Player, Tally Matrix Clock.

// ============================================================================
// MARK: - ARCHITECTURE
// ============================================================================
//
//  Models/
//    Bridge.swift           — Shared listening session model
//    BridgeRole.swift       — 5-tier role system: Host > Co-Host > Bouncer > Participant > Listener
//    Message.swift          — Chat messages within bridges
//    SavedPlaylist.swift    — User's saved playlists
//    StreamingService.swift — Service type enum
//    Track.swift            — Track model (cross-service)
//    User.swift             — User profile model
//
//  Services/
//    AppleMusicService.swift      — Apple Music MusicKit integration
//    PlaybackManager.swift        — Playback control coordination
//    SpotifyAuthManager.swift     — Spotify OAuth 2.0 PKCE flow
//    SpotifyService.swift         — Spotify Web API integration
//    StreamingServiceProtocol.swift — Protocol for service abstraction
//    TrackMatchingService.swift   — Cross-service track matching (find same song on both platforms)
//
//  Views/
//    Bridge/     — BridgeView, BridgeListView, MembersSheet, BridgeShareSheet, AddPlaylistToBridgeSheet, BridgeTradingCard
//    Components/ — AirPlayButton, BridgeCard, MiniPlayerBar, ServiceBadge, TrackRow
//    Home/       — HomeView (main landing)
//    Onboarding/ — OnboardingView, AgeGateView
//    Profile/    — ProfileView, PlaylistListView, PlaylistDetailView, PlaylistTransferSheet,
//                  SavedPlaylistDetailView, SpotifyDevicePicker, SpotifyLoginView
//    Search/     — SearchView
//    MainTabView.swift — Tab navigation
//    RootView.swift    — Root navigation coordinator

// ============================================================================
// MARK: - KEY FEATURES
// ============================================================================
//
//  Spotify Integration:
//    - OAuth 2.0 PKCE flow via ASWebAuthenticationSession
//    - Search, playback controls (play, skip forward/backward)
//    - Spotify Connect device picker (Apple TV, internet radio, any Spotify device)
//    - Profile import: display name, email, avatar from /me endpoint
//    - Playlist library with pagination
//
//  Apple Music Integration:
//    - MusicKit authorization
//    - Library access and search
//    - Track matching against Spotify catalog
//
//  Cross-Service Track Matching:
//    - TrackMatchingService finds equivalent tracks across Spotify and Apple Music
//    - Dual-search capability
//    - M3U export for Apple Music (MusicKit write APIs unavailable on macOS)
//
//  Social Features:
//    - Bridge naming/renaming
//    - Deep link invite system (tngrnGrvWr://bridge/<UUID>)
//    - Host/guest permission model with kick/ban
//    - 5-tier role system
//    - Onboarding with Spotify profile auto-import
//    - Golden apple badge (Apple Music) + green badge (Spotify)
//
//  Playlist Management (LimeWire-inspired):
//    - Split-screen browser: playlists top, tracks bottom
//    - Context menu: Transfer to Other Service, Export Playlist, Remove from Library
//    - 4-tab import sheet: Paste Link / Import Songs / Import File (CSV + M3U) / Apple Music
//    - CSV import: searches Spotify per track, creates playlist on account
//    - Follow/unfollow playlist APIs
//    - PlaylistTransferSheet for cross-service transfer
//    - M3U Export Sheet: Open in Music (macOS), Share via AirDrop, Copy Spotify Link

// ============================================================================
// MARK: - EASTER EGG
// ============================================================================
//
//  Claude Logo Easter Egg:
//    - Terra cotta starburst logo (512x512 PNG) in Assets.xcassets/ClaudeLogo.imageset/
//    - HomeView: 14x14 logo + "Engineered with Claude by Anthropic" under app title
//    - ProfileView About section: 20x20 logo + same text

// ============================================================================
// MARK: - ABOUT THIS APP
// ============================================================================
//
//  Tangerine GrooveWire
//  Version 1.0
//
//  Social listening, reimagined.
//
//  Engineered with Claude by Anthropic
//
//  Copyright (c) 2025 Michael Fluharty
//  Licensed under Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
//  https://creativecommons.org/licenses/by-sa/4.0/
//
//  You are free to share and adapt this work under the following terms:
//  - Attribution: Give appropriate credit, provide a link to the license
//  - ShareAlike: Distribute contributions under the same license
//
//  Website: https://fluharty.me
//  Contact: michael@fluharty.me
//  Feedback and suggestions welcome!

// ============================================================================
// MARK: - ROADMAP DECISIONS (2026 MAR 29 Brainstorm)
// ============================================================================
//
//  v1.0 IDENTITY:
//  - Playlist curation and cross-service transfer tool
//  - Playlists are the core — trading cards, not chat rooms
//  - Transfer is a headline feature but not the sole purpose
//  - Seed playlist builder (Spotify algorithm → liberate to your library)
//  - "Bridge" = bridging services/platforms/users, NOT a live listening room
//
//  v1.0 SOCIAL MODEL:
//  - No in-app messaging, DMs, or social feed — deliberate
//  - Social happens via iMessage, AirDrop, sneakernet, SharePlay
//  - Playlist trading cards are the social currency
//
//  v1.0 PLAYBACK & NAVIGATION:
//  - Full playback stays — GrooveWire is an iTunes replacement + Apple Music enhancement
//  - MiniPlayerBar, queue management, AirPlay, Spotify Connect all earn their place
//  - A pure playlist utility is too niche; playback gives daily-use value
//  - Discovery is NOT GrooveWire's job — Spotify/Apple Music do that,
//    GrooveWire makes their discoveries portable
//
//  v1.0 TAB STRUCTURE (decided 2026-03-29):
//    Tab 1: Home — app identity, hero image, stats, shortcuts to key features,
//            profile button (person outline, not gear), support link
//    Tab 2: GrooveWire — the bridge: transfer/import workflows, Spotify URL import,
//            seed playlist builder, CSV/M3U import
//    Tab 3: My Library — split-screen playlists + tracks, playback starts here
//  - Profile (service connections, theme, privacy, about) nests inside Home
//  - Library promoted from 2-taps-deep to top-level tab
//  - Home is a launchpad/command center, not just branding
//  - GrooveWire tab carries the app's name = the app's unique value
//
//  v1.0 CODE DISPOSITION (decided 2026-03-29):
//
//  REMOVE (preserved in git history):
//    Bridge.swift         — live room model, roles, kick/ban, vote queue
//    BridgeRole.swift     — 5-tier permission system
//    BridgeView.swift     — DJ Mode, live playback controls
//    MembersSheet.swift   — role management UI
//    Message.swift        — chat message model
//
//  REPURPOSE (rename, strip bridge references):
//    BridgeListView.swift      → LibraryListView (playlist browser for My Library tab)
//    AddPlaylistToBridgeSheet  → ImportPlaylistSheet (4-tab import for GrooveWire tab)
//    BridgeTradingCard.swift   → PlaylistTradingCard (shareable playlist card)
//    BridgeShareSheet.swift    → PlaylistShareSheet (share trading card via AirDrop/
//                                 iMessage/system share sheet, copy Spotify link,
//                                 remove age picker and bridge deep link)
//
//  KEEP AS-IS:
//    SeedPlaylistSheet.swift   — zero bridge dependency, works standalone
//
//  v2.0+ DEFERRED:
//  - DJ Mode / live synchronized listening (shelved, not scrapped)
//  - 5-tier role system, kick/ban, DJ succession
//  - Peer-to-peer bridge connections
//  - iMessage extension for playlist trading cards
//
//  v1.0 TRANSFER PATHS (decided 2026-03-29):
//    A) iOS Direct — MusicLibrary.createPlaylist(), headline feature
//    B) Mac M3U — reframed as "Export Playlist" (not transfer),
//       save to Downloads, user imports to Music.app and renames.
//       Support wiki + in-app FAQ must document the M3U workflow.
//    C) Mac AppleScript — create named playlists in Music.app via
//       scripting-targets. Build for v1.0, not deferred. The matching
//       engine produces Apple Music IDs; AppleScript is the last mile.
//
//  v1.0 DEVELOPMENT ORDER:
//    1. Mac app working (current state + AppleScript transfer)
//    2. iOS shakedown (verify direct transfer, adapt UI for phone)
//    3. Universal shakedown (both platforms, screenshot checklist)
//    4. Publish to App Store Connect
//
//  v1.0 MODEL CLEANUP (decided 2026-03-29):
//    Track — REMOVE: voteScore, voterIDs, isPinned, isBuried,
//            bridge relationship, vote()/removeVote()/userVote()/pin()/bury()
//            KEEP: sortOrder (playlist ordering), addedBy (import source)
//    User  — KEEP AS-IS. Profile 100% Spotify-compatible field structure.
//            Imported from Spotify GET /me, or manually created by Apple Music
//            users. COPPA fields stay for App Store review.
//            REMOVE: bridgeDisplayName() (bridge-room anonymization only)
//    SavedPlaylist — no changes needed, clean of bridge dependencies.
//
//  v1.0 CODE CLEANUP (decided 2026-03-29):
//    CONSOLIDATE DUPLICATES:
//      - CSV/M3U parsing → one shared utility (currently in 2 files)
//      - M3U generation → one shared utility (currently in 2 files)
//      - Spotify link copy → one shared helper (currently in 3 files)
//      - "Create bridge from playlist" → deleted with bridge removal
//    REMOVE DEAD CODE:
//      - pendingBridgeID in TngrnGrvWrApp (parsed, never navigated)
//      - enrichTrack() in TrackMatchingService (never called)
//      - Bridge.sortedUpcoming() (removed with Bridge.swift)
//      - SpotifyService.connect() no-op
//      - All Bridge back-compat helpers
//    KEEP FOR REPURPOSE:
//      - PlaylistTradingCard.renderToImage() — wire up for sharing
//    THEME SYSTEM:
//      - Ship v1.0 with Tangerine only (default/brand color)
//      - Remove AppTheme enum (8 themes), ThemeManager, theme picker from Profile
//      - Keep the EnvironmentKey plumbing (themeColor) — just hardcode to Tangerine
//      - Add theme selection back in a future update as a low-effort "what's new"
//    SECURITY/HYGIENE:
//      - Strip full token response print from SpotifyAuthManager
//      - Remove debug file write from TrackMatchingService (keep os.Logger)
//
//  v1.0 SUPPORT & DOCUMENTATION (decided 2026-03-29):
//    - Static in-app FAQ (no server dependency), accessible from Home tab
//    - GitHub wiki (CryoTunesPlayer template) linked from App Store Connect
//    - Docs needed: M3U export workflow + rename from "Internet Songs",
//      Spotify connection walkthrough, Apple Music permissions,
//      "What is GrooveWire?" overview
//
//  v1.0 FEATURE MANIFEST (finalized 2026-03-29):
//
//  CORE:
//    - Spotify OAuth + library sync (playlists with full tracks)
//    - Apple Music MusicKit (library access, search, playlist create on iOS)
//    - Cross-service track matching (Levenshtein + normalization)
//    - Dual-service search with deduplication
//
//  TRANSFER:
//    - iOS: direct playlist creation via MusicLibrary.createPlaylist()
//    - Mac: AppleScript named playlist creation in Music.app (to build)
//    - Mac: M3U export (save to Downloads, AirDrop, Open in Music)
//    - Spotify URL import (paste link → fetch tracks → match → save)
//    - CSV/M3U file import
//    - Manual song entry (title, artist per line)
//    - Apple Music library playlist import
//
//  PLAYBACK:
//    - Full playback via Spotify Connect and Apple Music MusicKit
//    - MiniPlayerBar (always visible during playback)
//    - Queue management (skip, back, auto-advance, wrap-around)
//    - AirPlay output (Apple Music)
//    - Spotify device picker — doubles as Spotify remote control
//      for external speakers, TVs, phones, etc.
//
//  LIBRARY:
//    - Split-screen browser (iTunes-inspired: playlists + tracks)
//    - Seed playlist builder (pick song → recommendations → save)
//    - Playlist trading cards (visual, shareable)
//    - Playlist privacy toggle (public/private)
//    - Spotify playlist follow/unfollow sync
//
//  PROFILE:
//    - Spotify profile import (name, email, avatar)
//    - Manual profile for Apple Music-only users
//    - Service connection management
//    - COPPA compliance (birthday, age gating, parental consent)
//    - Spotify device picker
//
//  NAVIGATION:
//    - Tab 1: Home (landing page — identity, stats, shortcuts, profile, support FAQ)
//    - Tab 2: GrooveWire (transfer/import workflows)
//    - Tab 3: My Library (split-screen + playback)
//    - Onboarding + AgeGate first-launch flow
//
//  SUPPORT:
//    - Static in-app FAQ (Home tab)
//    - GitHub wiki (CryoTunesPlayer template, linked from App Store Connect)
//
//  NOT IN v1.0 (deferred):
//    - DJ Mode / live listening
//    - Bridge rooms / role system / kick-ban
//    - In-app messaging
//    - Peer-to-peer connections
//    - iMessage extension
//    - Theme picker (Tangerine only for v1.0)
//    - Spotify URL import without Spotify account
//
//  FUTURE / BACKLOG:
//    - iTunes-inspired features: iPod integrations, song ratings
//    - Additional streaming services as discovered
//    - Theme selection (8 themes already built, add back post-v1.0)
//    - "For You" / Radio Mode: seed track → auto-generated queue
//      (recommendation engine partially built in AppleMusicService)
//    - iMessage extension for playlist trading cards
//
//  OPEN QUESTIONS:
//  - Import Spotify URL workflow for non-Spotify users (fetch public
//    playlist without Spotify account — may need server component)

// ============================================================================
// MARK: - PLANNED FEATURES
// ============================================================================
//
//  - "For You" / Genius-style recommendations: Apple Music's Create Station
//    and autoplay features can generate infinite playlists from a seed song.
//    Add to GrooveWire bridges as a "Radio Mode" — host picks a seed track,
//    Apple Music generates the queue automatically. Explore MusicKit
//    Station/Recommendation APIs for personalized suggestions within bridges.
//    (Noted 2026 MAR 22)

// ============================================================================
// MARK: - KNOWN ISSUES
// ============================================================================
//
//  (none currently)

// ============================================================================
// MARK: - SWIFT CODE EVALUATION (2026 MAR 29)
// ============================================================================
//
//  Full line-by-line audit of all 44 Swift files (~8,300 lines).
//  Performed by Claude Code during roadmap reconstruction session.
//
//  ── HIDDEN / UNDOCUMENTED FEATURES ──
//
//  1. VOTE-SORTED QUEUE (Bridge.swift:186-227)
//     Bridge has a full vote-based queue sorting algorithm.
//     Tracks with positive votes bubble up, negative votes sink down.
//     Each vote point = one position swap (bubble sort with vote weighting).
//     Pinned tracks jump to front, buried tracks drop to back.
//     This is a fully functional DJ queue reorder system.
//     NOT DOCUMENTED in the feature list. NOT exposed in any UI.
//     The BridgeView uses sortedTracks (sortOrder-based) instead.
//
//  2. DJ MODE (BridgeView.swift:21, :235-240, :270-280)
//     Hidden toggle in the bridge menu: "DJ Mode".
//     When ON: thumbs up moves track to FRONT of queue, thumbs down to BACK.
//     When OFF: thumbs up/down nudge one position only.
//     Context menu labels change: "Play Next (DJ)" / "Play Last (DJ)".
//     NOT DOCUMENTED anywhere. Discovered only by reading BridgeView.
//
//  3. QUEUE WRAP-AROUND (PlaybackManager.swift:162-166)
//     When the queue reaches the last track, playback wraps to track 0.
//     Auto-advance via 2-second polling timer (checkPlaybackProgress).
//     This creates infinite loop playback — the queue never stops.
//
//  4. TRACK ENRICHMENT (TrackMatchingService.swift:121-146)
//     enrichTrack() fills in the missing service ID on a track.
//     If a track has Spotify but no Apple Music, it searches Apple Music
//     and writes the ID back onto the Track model.
//     This is called nowhere in the current codebase — it's a utility
//     waiting to be wired up. Could auto-enrich tracks on import.
//
//  5. APPLE MUSIC RECOMMENDATIONS ENGINE (AppleMusicService.swift:140-166)
//     getRecommendations(seedTrackID:limit:) generates similar tracks
//     by fetching the seed song's artist + first genre, then searching
//     the Apple Music catalog. Used by SeedPlaylistSheet but not
//     documented in the feature list. This IS the "Radio Mode" seed
//     mentioned in PLANNED FEATURES — it's already partially built.
//
//  6. DUAL-SERVICE SEARCH WITH DEDUP (TrackMatchingService.swift:183-201)
//     searchBothServices() searches Spotify and Apple Music in parallel
//     using async let, then merges/deduplicates results. If a track
//     appears on both services, it merges the IDs onto one Track object.
//     Used by SearchView and SeedPlaylistSheet.
//
//  7. LEVENSHTEIN DISTANCE MATCHING (TrackMatchingService.swift:262-300)
//     Full Levenshtein edit distance implementation for fuzzy title matching.
//     Threshold: >0.8 similarity + artist match = "near" confidence.
//     Also strips 20+ common suffixes (remastered, deluxe, live, acoustic,
//     explicit, clean, radio edit, feat., bonus track, single, etc).
//
//  8. SEED PLAYLIST BUILDER (SeedPlaylistSheet.swift — full file)
//     3-phase wizard: Search → Review → Name.
//     Pick any song, get 25 recommendations, cherry-pick tracks,
//     name and save as a playlist (locally + on Spotify if connected).
//     Seed track is inserted at position 0 automatically.
//     All recommendations pre-selected by default.
//     Accessible from HomeView "Build Playlist from Song" AND
//     from BridgeView menu, but NOT from the Profile or Library.
//
//  9. BRIDGE TRADING CARD WITH IMAGE EXPORT (BridgeTradingCard.swift:106-118)
//     renderToImage() uses ImageRenderer at 3x scale to produce a
//     shareable PNG of the trading card. Supports both iOS (UIImage)
//     and macOS (NSImage). The render function exists but is NEVER
//     called — the trading card is only used visually in BridgeShareSheet.
//
//  10. COPPA COMPLIANCE SYSTEM (User.swift, AgeGateView.swift, OnboardingView.swift)
//      Full age-gating: child (<13), teen (13-17), adult (18+).
//      Children: always "Listener" in bridges, name hidden, profile locked private.
//      Teens: private by default, name shown only with parental consent.
//      Adults: can toggle public/private.
//      Parental consent dialog with 3 options (approve / continue without / cancel).
//      AgeGateView is a separate catch-up screen for existing users who
//      didn't have birthday set. Privacy auto-computed from age category.
//      Contact method (email or phone) required — COPPA verifiable contact.
//      User.bridgeDisplayName() returns "Listener" for anonymous minors.
//
//  11. SPOTIFY API FORWARD-COMPAT (SpotifyService.swift:85, :226)
//      Two comments note "Feb 2026 API" changes:
//      - "tracks" renamed to "items" in playlist response — code checks both.
//      - "track" renamed to "item" in playlist track items — code checks both.
//      This dual-path parsing prevents breakage if Spotify rolls back changes.
//
//  12. SPOTIFY DEVICE AUTO-RECOVERY (SpotifyService.swift:354-376)
//      play() has a 404 retry: if no active device found, it refreshes
//      the device list and retries once with the newly discovered device.
//      Silent fallback — user never sees the 404.
//
//  13. DEEP LINK HANDLER (TngrnGrvWrApp.swift:65-73)
//      Parses tngrnGrvWr://bridge/<UUID> URLs. Sets pendingBridgeID.
//      BUT: pendingBridgeID is never read by any view. The deep link
//      is parsed and printed to console but never acted on. Dead code path.
//
//  14. ESCAPE KEY DESELECT (BridgeView.swift:38-42)
//      Hidden keyboard shortcut: pressing Escape clears the selected track
//      highlight in the queue. macOS-only convenience, not documented.
//
//  15. KEYBOARD SHORTCUT SUPPORT POTENTIAL
//      BridgeView uses .keyboardShortcut(.escape) — the only keyboard
//      shortcut in the app. No other views use keyboard shortcuts.
//      No Cmd+F for search, no spacebar for play/pause, etc.
//
//  16. M3U UTType EXTENSION (PlaylistListView.swift:888-890)
//      Custom UTType declared: UTType.m3uPlaylist for .m3u files.
//      Used by file importers across multiple sheets.
//
//  17. DEBUG LOG TO TEMP FILE (TrackMatchingService.swift:8-19)
//      Every match operation writes to groovewire-match-debug.log
//      in the system temp directory. Also logs via os.Logger.
//      Diagnostic file persists between launches — could grow large.
//
//  18. SPOTIFY FOLLOW/UNFOLLOW PLAYLIST (SpotifyService.swift:110-137)
//      Full follow/unfollow API for playlists. Follow is used when
//      saving a playlist from a link. Unfollow is called when deleting
//      a saved playlist (PlaylistListView:299) — removes it from
//      the user's Spotify library too. Not documented.
//
//  19. SPOTIFY CREATE PLAYLIST WITH BATCHED ADDS (SpotifyService.swift:139-184)
//      Creates playlist via POST /me/playlists, then adds tracks in
//      batches of 100 (Spotify API limit). Used by SeedPlaylistSheet,
//      BridgeView (save as playlist), and PlaylistTransferSheet.
//
//  20. SAVED PLAYLIST PRIVACY TOGGLE (PlaylistListView context menu)
//      Right-click any saved playlist → "Make Public" / "Make Private".
//      Toggles isPublic on the SavedPlaylist model. This is the
//      foundation for the v2.0 peer-to-peer playlist sharing concept
//      (private playlists visible but not downloadable in bridges).
//
//  21. ADD TRACKS TO EXISTING PLAYLIST (PlaylistListView:1051-1214)
//      AddTracksToPlaylistSheet: search both services, tap + to add
//      tracks one at a time to a specific saved playlist.
//      Deduplicates Apple Music results against Spotify results
//      by title+artist key. Context menu → "Add Tracks" triggers it.
//
//  22. APPLE MUSIC PLAYLIST IMPORT (PlaylistListView:499-544, :663-711)
//      Full Apple Music tab in AddPlaylistSheet. Lists all user's
//      Apple Music library playlists, fetches tracks via MusicKit,
//      saves as a local SavedPlaylist. Lazy-loads on tab switch.
//
//  23. IOS-ONLY APPLE MUSIC PLAYLIST CREATION (AppleMusicService.swift:107-136)
//      createPlaylist() is wrapped in #if os(iOS). On Mac it throws
//      .notAvailableOnMac. Uses MusicLibrary.shared.createPlaylist()
//      to create a real playlist in the user's Apple Music library.
//      Resolves each track ID to a Song object before adding.
//      This is the iOS direct transfer path from the morning notes.
//
//  24. BRIDGE-TO-PLAYLIST SAVE WITH SPOTIFY SYNC (BridgeView.swift:420-478)
//      "Save as Playlist" creates a Spotify playlist AND a local
//      SavedPlaylist simultaneously. If Spotify creation fails,
//      local save still succeeds (graceful degradation).
//
//  25. SPLIT-SCREEN LIBRARY BROWSER (PlaylistListView.swift:42-168)
//      Top half: playlist list. Bottom half: track list for selected playlist.
//      "All Songs" view flattens every saved playlist into one list.
//      This is the LimeWire-inspired split view from the design doc.
//
//  26. SPOTIFY TOKEN LOGGING (SpotifyAuthManager.swift:127-131)
//      parseTokenResponse() prints the FULL token response and granted
//      scopes to console. The access token itself is included in the
//      raw JSON dump. Potential security concern for shared logs.
//
//  27. SEARCH EMOJI LOGGING (SpotifyService.swift:307-318)
//      search() prints request URL, token prefix (first 10 chars),
//      HTTP status, and first 500 chars of response with emoji prefixes.
//      Useful for debugging but noisy in production.
//
//  28. BRIDGE LIST: INLINE TRACK MANAGEMENT (BridgeListView.swift:384-417)
//      Pin/bury/remove buttons appear next to each track in the bridge list.
//      Pin uses track.pin() (→ front), bury uses track.bury() (→ back).
//      These call Track model methods that set isPinned/isBuried flags.
//      The vote-sorted queue in Bridge.swift respects these flags.
//
//  29. ONMOVE DRAG REORDER (BridgeView.swift:309-323)
//      Tracks in BridgeView can be drag-reordered. On move:
//      recalculates sortOrder, syncs to PlaybackManager queue,
//      preserves current track position. Full manual queue control.
//
//  30. SUBSCRIPTION CHECK (AppleMusicService.swift:26-35)
//      checkSubscription() verifies canPlayCatalogContent.
//      hasSubscription flag is set on ProfileView.task{} load.
//      The golden Apple Music badge (ServiceBadge) shows when
//      hasSubscription is true, not just when connected.
//
//  ── DUPLICATE / REDUNDANT CODE ──
//
//  A. CSV/M3U PARSING — duplicated in 2 places:
//     - AddPlaylistToBridgeSheet.swift:379-426
//     - PlaylistListView.swift (AddPlaylistSheet):833-883
//     Identical logic, identical SongEntry struct. Should be one utility.
//
//  B. CREATE BRIDGE FROM PLAYLIST — duplicated in 3 places:
//     - BridgeListView.swift:297-322
//     - PlaylistListView.swift:269-294
//     - SavedPlaylistDetailView.swift:134-160
//     All copy tracks, insert bridge, save context. Same pattern.
//
//  C. M3U GENERATION — duplicated in 2 places:
//     - PlaylistTransferToMusicSheet.swift:548-583
//     - PlaylistListView.swift (M3UExportSheet):1029-1048
//     Slightly different formats but same concept.
//
//  D. SPOTIFY LINK COPY — duplicated in 3 places:
//     - PlaylistTransferToMusicSheet export view
//     - M3UExportSheet
//     - BridgeShareSheet
//     All copy to pasteboard with "Copied!" feedback.
//
//  ── DEAD CODE / UNUSED PATHS ──
//
//  1. pendingBridgeID (TngrnGrvWrApp.swift:18) — set by deep link handler,
//     never read. Deep links parse but don't navigate.
//
//  2. enrichTrack() (TrackMatchingService.swift:121) — never called.
//
//  3. BridgeTradingCard.renderToImage() — never called.
//
//  4. Bridge.sortedUpcoming() — vote-sorted queue function, never called.
//     BridgeView uses its own sortedTracks computed property instead.
//
//  5. StreamingServiceProtocol.connect() — SpotifyService.connect() is a no-op.
//
//  6. Bridge back-compat helpers (guestIDs, bouncerIDs, guestsCanInvite,
//     isBouncer, demoteFromBouncer) — appear unused by any view.
//
//  ── OBSERVATIONS ──
//
//  - Zero external dependencies. Everything is Apple-native frameworks.
//  - All JSON parsing is manual (JSONSerialization). No Codable for API responses.
//  - CloudKit container configured but no sync logic implemented.
//  - SwiftData models are local-only despite CloudKit entitlement.
//  - No unit tests cover any service, model, or matching logic.
//  - 8 AppTheme colors with icons, persisted via UserDefaults.
//  - ThemeManager creates a custom EnvironmentKey for themeColor.
//  - macOS window defaults to 700x650 via .defaultSize().
//  - All print() statements use [ServiceName] prefix convention.
//  - Haptic feedback on iOS when adding tracks to bridge (SearchView:159).
//  - AppleMusicService.disconnect() sets status to .notDetermined (not .denied).
//

// ============================================================================
// MARK: - DEVELOPER NOTES LOG
// ============================================================================
//
//  2026 MAR 29 — Full code evaluation: 30 hidden/undocumented features,
//                4 duplicate code patterns, 6 dead code paths documented.
//                Vote-sorted queue, DJ Mode, COPPA system, seed playlist
//                builder, trading card export, and enrichTrack() discovered
//                as undocumented. (Claude Code)
//  2026 MAR 19 — Audit: fixed import sheet (4 tabs not 3), context menu
//                description. Fixed M3U export: now runs TrackMatchingService
//                to resolve Apple Music IDs before generating file. (Claude Code)
//  2026 MAR 18 — Developer notes file created with project architecture,
//                features inventory, and About This App section. (Claude Code)
//
