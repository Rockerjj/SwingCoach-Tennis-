import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if !authService.isAuthenticated {
                SignInView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
    }
}
