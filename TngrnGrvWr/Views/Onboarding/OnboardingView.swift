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
    @State private var birthday = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var hasPickedBirthday = false
    @State private var showParentalConsent = false
    @State private var parentalConsent = false
    var onComplete: () -> Void

    private var computedAge: AgeCategory {
        User.computeAgeCategory(from: birthday)
    }

    private var hasContact: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty ||
        !phone.trimmingCharacters(in: .whitespaces).isEmpty
    }

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

                DatePicker(
                    "Birthday",
                    selection: $birthday,
                    in: Calendar.current.date(byAdding: .year, value: -120, to: Date())!...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.automatic)
                .onChange(of: birthday) { _, _ in
                    hasPickedBirthday = true
                }

                if hasPickedBirthday {
                    ageCategoryNotice
                }

                TextField("Email (required if no phone)", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    #endif

                TextField("Phone (required if no email)", text: $phone)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.telephoneNumber)
                    #if os(iOS)
                    .keyboardType(.phonePad)
                    #endif
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                if computedAge == .child || computedAge == .teen {
                    showParentalConsent = true
                } else {
                    createUser()
                }
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
        .sheet(isPresented: $showSpotifyLogin, onDismiss: {
            // When the login sheet closes, check if auth succeeded
            if spotifyService.isConnected && !importedFromSpotify {
                Task { await importSpotifyProfile() }
            }
        }) {
            SpotifyLoginView(authManager: spotifyService.authManager)
        }
        .onChange(of: spotifyService.isConnected) { _, connected in
            if connected && !importedFromSpotify {
                Task { await importSpotifyProfile() }
            }
        }
        .alert("Parental Notice", isPresented: $showParentalConsent) {
            Button("My parent/guardian approves") {
                parentalConsent = true
                createUser()
            }
            Button("Continue without consent") {
                parentalConsent = false
                createUser()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if computedAge == .child {
                Text("Users under 13 will always appear as \"Listener\" in bridges. A parent or guardian must approve use of this app.")
            } else {
                Text("Users 13-17 are private by default. With parental consent, your screen name can be shown in bridges.")
            }
        }
    }

    @ViewBuilder
    private var ageCategoryNotice: some View {
        switch computedAge {
        case .child:
            Label("Under 13 — profile will be private, name hidden in bridges", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        case .teen:
            Label("13-17 — profile is private by default", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.blue)
        case .adult:
            Label("18+ — you can choose public or private profile", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.green)
        case .unknown:
            EmptyView()
        }
    }

    private var canContinue: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        hasPickedBirthday &&
        hasContact
    }

    private func importSpotifyProfile() async {
        print("[Onboarding] Fetching Spotify profile... isConnected=\(spotifyService.isConnected)")
        do {
            let profile = try await spotifyService.fetchProfile()
            print("[Onboarding] Got profile: name=\(profile.displayName ?? "nil"), email=\(profile.email ?? "nil"), avatar=\(profile.avatarURL != nil ? "yes" : "nil")")
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
            streamingService: importedFromSpotify ? .spotify : .none,
            avatarURL: avatarURL,
            birthday: birthday,
            hasCompletedAgeGate: true,
            parentalConsentAcknowledged: parentalConsent
        )
        modelContext.insert(user)
        try? modelContext.save()
        print("[Onboarding] User saved: \(user.displayName), age=\(user.ageCategory), email=\(user.email ?? "nil")")
        onComplete()
    }
}
