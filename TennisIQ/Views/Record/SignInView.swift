import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authService: AuthService
    let theme = DesignSystem.current

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: Spacing.xxl) {
                Spacer()

                VStack(spacing: Spacing.lg) {
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 72, weight: .thin))
                        .foregroundStyle(theme.accent)

                    Text("TennisCoach")
                        .font(AppFont.display(size: 36))
                        .foregroundStyle(theme.textPrimary)
                    +
                    Text("AI")
                        .font(AppFont.display(size: 36))
                        .foregroundStyle(theme.accent)

                    Text("World-class coaching\nthrough your phone")
                        .font(AppFont.body(size: 18))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                VStack(spacing: Spacing.md) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        authService.handleSignInResult(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .cornerRadius(Radius.md)

                    Button {
                        authService.continueAsGuest()
                    } label: {
                        Text("Continue as Guest")
                            .font(AppFont.body(size: 16, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .stroke(theme.textTertiary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    Text("Your data stays private. Videos never leave your device.")
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
        }
    }
}
