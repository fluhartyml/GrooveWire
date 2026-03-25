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
//  Social listening app — synchronized playback over Apple Music + Spotify.
//  Core concept: "bridges" (shared listening sessions).
//  Cross-platform social layer, not a music player/host.
//  Winamp/LimeWire-era nostalgia with modern Apple design.
//  Discovery through people, not just algorithms.

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
// MARK: - DEVELOPER NOTES LOG
// ============================================================================
//
//  2026 MAR 19 — Audit: fixed import sheet (4 tabs not 3), context menu
//                description. Fixed M3U export: now runs TrackMatchingService
//                to resolve Apple Music IDs before generating file. (Claude Code)
//  2026 MAR 18 — Developer notes file created with project architecture,
//                features inventory, and About This App section. (Claude Code)
//
