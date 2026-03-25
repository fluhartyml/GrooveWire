import SwiftUI
import SwiftData
import MusicKit

struct ProfileView: View {
    var onBridgeCreated: ((UUID) -> Void)?

    @Environment(SpotifyService.self) private var spotifyService
    @Environment(AppleMusicService.self) private var appleMusicService
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Environment(ThemeManager.self) private var themeManager
    @State private var showSpotifyLogin = false

    private var currentUser: User? { users.first }

    var body: some View {
        List {
            if let user = currentUser {
                Section("Identity") {
                    HStack(spacing: 14) {
                        if let url = user.avatarURL, let imageURL = URL(string: url) {
                            AsyncImage(url: imageURL) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle().fill(.quaternary)
                                    .overlay { Image(systemName: "person.fill").foregroundStyle(.secondary) }
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(user.displayName)
                                    .font(.headline)
                                if appleMusicService.hasSubscription {
                                    ServiceBadge(service: .appleMusic)
                                }
                                if spotifyService.isConnected {
                                    ServiceBadge(service: .spotify)
                                }
                            }
                            if let email = user.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let phone = user.phoneNumber {
                                Text(phone)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Streaming Services") {
                spotifyRow
                appleMusicRow
            }

            if spotifyService.isConnected {
                Section {
                    SpotifyDevicePicker()
                } header: {
                    Text("Spotify Remote")
                } footer: {
                    Text("GrooveWire controls Spotify on your other devices. Select where you want music to play — your Mac, TV, speaker, or phone. Spotify must be open on the target device.")
                }
            }

            if spotifyService.isConnected {
                Section {
                    NavigationLink(destination: PlaylistListView(onBridgeCreated: onBridgeCreated)) {
                        Label("My Library", systemImage: "rectangle.split.1x2")
                    }
                } header: {
                    Text("Spotify Library")
                } footer: {
                    Text("Browse your playlists and songs. Load them into a GrooveWire Bridge.")
                }
            }

            if let user = currentUser {
                Section("Privacy") {
                    if let birthday = user.birthday {
                        HStack {
                            Label("Birthday", systemImage: "birthday.cake")
                            Spacer()
                            Text(birthday, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Label("Age Group", systemImage: "person.crop.circle.badge.clock")
                        Spacer()
                        Text(ageCategoryLabel(user.ageCategory))
                            .foregroundStyle(.secondary)
                    }

                    if user.canChangePrivacy {
                        Picker(selection: Binding(
                            get: { user.privacyLevel },
                            set: { user.privacyLevel = $0 }
                        )) {
                            Text("Public").tag("public")
                            Text("Private").tag("private")
                        } label: {
                            Label("Profile Visibility", systemImage: "eye")
                        }
                    } else {
                        HStack {
                            Label("Profile Visibility", systemImage: "lock.fill")
                            Spacer()
                            Text("Private (age-restricted)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Appearance") {
                @Bindable var tm = themeManager
                Picker("Theme", selection: $tm.currentTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Label(theme.displayName, systemImage: theme.icon)
                            .tag(theme)
                    }
                }
            }

            Section("About") {
                Label("Tangerine GrooveWire", systemImage: "antenna.radiowaves.left.and.right")

                HStack(spacing: 6) {
                    Image("ClaudeLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("Engineered with Claude by Anthropic")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showSpotifyLogin) {
            SpotifyLoginView(authManager: spotifyService.authManager)
        }
        .task {
            if spotifyService.isConnected {
                try? await spotifyService.fetchDevices()
            }
            if appleMusicService.isConnected {
                await appleMusicService.checkSubscription()
            }
        }
        .onChange(of: spotifyService.isConnected) { _, connected in
            if connected {
                Task { await enrichFromSpotify() }
            }
        }
    }

    private func ageCategoryLabel(_ category: AgeCategory) -> String {
        switch category {
        case .child: return "Under 13"
        case .teen: return "13-17"
        case .adult: return "18+"
        case .unknown: return "Not set"
        }
    }

    private func enrichFromSpotify() async {
        guard let user = currentUser else { return }
        do {
            let profile = try await spotifyService.fetchProfile()
            if user.avatarURL == nil, let url = profile.avatarURL {
                user.avatarURL = url
            }
            if user.email == nil, let email = profile.email {
                user.email = email
            }
        } catch {
            print("[Profile] Spotify enrichment failed: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private var spotifyRow: some View {
        if spotifyService.isConnected {
            HStack(spacing: 8) {
                Label {
                    HStack(spacing: 6) {
                        Text("Spotify")
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                } icon: {
                    Image(systemName: "dot.radiowaves.left.and.right")
                }
                .foregroundStyle(.primary)

                Spacer()

                Button {
                    spotifyService.disconnect()
                } label: {
                    Image(systemName: "circle.slash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Disconnect")
            }
        } else {
            Button {
                showSpotifyLogin = true
            } label: {
                Label("Connect Spotify", systemImage: "dot.radiowaves.left.and.right")
            }
        }
    }

    @ViewBuilder
    private var appleMusicRow: some View {
        if appleMusicService.isConnected {
            HStack(spacing: 8) {
                Label {
                    HStack(spacing: 6) {
                        Text("Apple Music")
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                } icon: {
                    Image(systemName: "apple.logo")
                }
                .foregroundStyle(.primary)

                Spacer()

                Button {
                    appleMusicService.disconnect()
                } label: {
                    Image(systemName: "circle.slash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Disconnect")
            }
        } else {
            Button {
                Task { try? await appleMusicService.connect() }
            } label: {
                Label("Connect Apple Music", systemImage: "apple.logo")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}
