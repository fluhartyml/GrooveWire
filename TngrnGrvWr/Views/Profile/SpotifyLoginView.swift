import SwiftUI
import AuthenticationServices

struct SpotifyLoginView: View {
    let authManager: SpotifyAuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var error: String?
    @State private var authSession: ASWebAuthenticationSession?
    @State private var contextProvider = AuthContextProvider()

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Connect Spotify")
                .font(.title2.bold())

            Text("Sign in to your Spotify account to search and play music on GrooveWire.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button {
                startAuth()
            } label: {
                Label("Sign in with Spotify", systemImage: "arrow.right.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding()
    }

    private func startAuth() {
        let url = authManager.generateAuthURL()

        authSession = ASWebAuthenticationSession(
            url: url,
            callback: .customScheme("tngrnGrvWr")
        ) { callbackURL, sessionError in
            if let sessionError {
                error = sessionError.localizedDescription
                return
            }
            guard let callbackURL else {
                error = "No callback received"
                return
            }
            Task {
                do {
                    try await authManager.handleCallback(url: callbackURL)
                    await MainActor.run { dismiss() }
                } catch {
                    await MainActor.run { self.error = error.localizedDescription }
                }
            }
        }
        authSession?.presentationContextProvider = contextProvider
        authSession?.prefersEphemeralWebBrowserSession = false
        authSession?.start()
    }
}

// MARK: - Presentation Context

private class AuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #else
        return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
        #endif
    }
}
