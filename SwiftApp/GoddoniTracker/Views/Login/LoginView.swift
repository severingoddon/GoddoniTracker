import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        ZStack {
            GTColor.bgDeepest.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(GTColor.gradient, lineWidth: 2.5)
                        .frame(width: 80, height: 80)
                    Text("G")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(GTColor.gradient)
                }

                VStack(spacing: 8) {
                    Text("GoddoniTracker")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(GTColor.gradient)
                    Text("Behalte den Ueberblick\nueber deine Ausgaben.")
                        .font(.system(size: 15))
                        .foregroundStyle(GTColor.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button {
                    startGoogleLogin()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 20))
                        Text("Mit Google anmelden")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(GTColor.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)

                Spacer().frame(height: 60)
            }
        }
    }

    private func startGoogleLogin() {
        guard let loginURL = authManager.startGoogleLogin() else { return }

        let session = ASWebAuthenticationSession(
            url: loginURL,
            callbackURLScheme: "goddonitracker"
        ) { callbackURL, error in
            guard let callbackURL, error == nil else { return }
            if let token = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "token" })?.value {
                authManager.saveToken(token)
            }
        }
        session.prefersEphemeralWebBrowserSession = false
        session.presentationContextProvider = LoginPresentationContext.shared
        session.start()
    }
}

final class LoginPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = LoginPresentationContext()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}
