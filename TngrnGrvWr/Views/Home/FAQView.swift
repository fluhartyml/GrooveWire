import SwiftUI

/// Static in-app FAQ. Covers core workflows for v1.0.
struct FAQView: View {
    @Environment(\.themeColor) private var themeColor

    var body: some View {
        List {
            Section("About GrooveWire") {
                faqItem(
                    question: "What is GrooveWire?",
                    answer: "GrooveWire bridges the gap between streaming services. It lets you transfer playlists between Spotify and Apple Music, build new playlists from seed songs, and manage your music library across services."
                )
            }

            Section("Transferring Playlists") {
                faqItem(
                    question: "How do I transfer a Spotify playlist to Apple Music?",
                    answer: "Go to the GrooveWire tab, tap Import Playlist, and paste a Spotify playlist link. GrooveWire will match every track against the Apple Music catalog, then let you review the matches before transferring."
                )

                #if os(iOS)
                faqItem(
                    question: "How does the transfer work on iPhone?",
                    answer: "On iPhone and iPad, GrooveWire creates a real playlist directly in your Apple Music library with the correct name and all matched tracks. Open Apple Music and your playlist will be there."
                )
                #endif

                #if os(macOS)
                faqItem(
                    question: "How does the transfer work on Mac?",
                    answer: "On Mac, GrooveWire can create a named playlist in Music.app via AppleScript, or export an M3U file. The AppleScript method creates the playlist with the correct name automatically."
                )

                faqItem(
                    question: "What is M3U export?",
                    answer: "M3U is a standard playlist file format. When you export as M3U, the file is saved to your Downloads folder. You can then open it in Music.app (the tracks will import, but the playlist will be named \"Internet Songs\" — rename it manually). You can also share the M3U file via AirDrop or Messages."
                )

                faqItem(
                    question: "Why does Music.app call my playlist \"Internet Songs\"?",
                    answer: "Music.app ignores the playlist name in M3U files — this is an Apple limitation. To get the correct name automatically, use the \"Transfer to Apple Music\" option instead of M3U export. If you already exported as M3U, just right-click the playlist in Music.app and rename it."
                )
                #endif
            }

            Section("Connecting Services") {
                faqItem(
                    question: "How do I connect Spotify?",
                    answer: "Go to Home → Profile → Streaming Services → Connect Spotify. You'll sign in through Spotify's website. GrooveWire uses OAuth (no password stored) and needs permission to read your playlists and control playback."
                )

                faqItem(
                    question: "How do I connect Apple Music?",
                    answer: "Go to Home → Profile → Streaming Services → Connect Apple Music. You'll be prompted to allow GrooveWire access to your music library through MusicKit. An active Apple Music subscription is required for full functionality."
                )

                faqItem(
                    question: "Do I need both services connected?",
                    answer: "No. You can use GrooveWire with just one service. But transferring between services requires both to be connected so GrooveWire can match tracks across catalogs."
                )
            }

            Section("Building Playlists") {
                faqItem(
                    question: "What is the Seed Playlist Builder?",
                    answer: "Pick any song as a \"seed\" and GrooveWire will find 25 similar tracks. You can review, select, and save them as a new playlist — both locally and on your connected streaming service."
                )

                faqItem(
                    question: "How does track matching work?",
                    answer: "GrooveWire searches the target service for each track by artist and title. It normalizes names (stripping \"Remastered\", \"Deluxe\", etc.) and uses fuzzy matching to handle slight differences. Matches are shown as exact (green), near (yellow), or not found (red)."
                )
            }

            Section("Privacy") {
                faqItem(
                    question: "What data does GrooveWire collect?",
                    answer: "GrooveWire stores your profile and playlist data on your device only. No data is sent to GrooveWire servers — there are no GrooveWire servers. Your Spotify credentials are handled by Spotify's OAuth system and stored in your device's Keychain."
                )
            }
        }
        .navigationTitle("Support")
    }

    @ViewBuilder
    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question)
                .font(.subheadline.weight(.medium))
            Text(answer)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        FAQView()
    }
}
