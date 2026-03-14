import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SpotifyService.self) private var spotifyService
    @State private var displayName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var avatarURL: String?
    @State private var showSpotifyLogin = false
    @State private var importedFromSpotify = false
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                // Avatar or icon
                if let url = avatarURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)
                }

                Text("Welcome to GrooveWire")
                    .font(.largeTitle.bold())

                Text("Set up your profile so friends can find you and hosts know who's in their bridge.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            // Spotify import button
            if !importedFromSpotify {
                Button {
                    showSpotifyLogin = true
                } label: {
                    Label("Import from Spotify", systemImage: "dot.radiowaves.left.and.right")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
            } else {
                Label("Imported from Spotify", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .padding(.bottom, 12)
            }

            VStack(spacing: 16) {
                TextField("Display Name", text: $displayName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                    #if os(iOS)
                    .autocapitalization(.words)
                    #endif

                TextField("Email (optional)", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    #endif

                TextField("Phone (optional)", text: $phone)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.telephoneNumber)
                    #if os(iOS)
                    .keyboardType(.phonePad)
                    #endif
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                createUser()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canContinue ? .orange : .gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canContinue)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showSpotifyLogin) {
            SpotifyLoginView(authManager: spotifyService.authManager)
        }
        .onChange(of: spotifyService.isConnected) { _, connected in
            if connected {
                Task { await importSpotifyProfile() }
            }
        }
    }

    private var canContinue: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func importSpotifyProfile() async {
        do {
            let profile = try await spotifyService.fetchProfile()
            if displayName.isEmpty, let name = profile.displayName {
                displayName = name
            }
            if email.isEmpty, let profileEmail = profile.email {
                email = profileEmail
            }
            if avatarURL == nil {
                avatarURL = profile.avatarURL
            }
            importedFromSpotify = true
        } catch {
            print("[Onboarding] Spotify profile import failed: \(error.localizedDescription)")
        }
    }

    private func createUser() {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        let user = User(
            displayName: name,
            email: email.isEmpty ? nil : email.trimmingCharacters(in: .whitespaces),
            phoneNumber: phone.isEmpty ? nil : phone.trimmingCharacters(in: .whitespaces),
            avatarURL: avatarURL
        )
        modelContext.insert(user)
        onComplete()
    }
}
