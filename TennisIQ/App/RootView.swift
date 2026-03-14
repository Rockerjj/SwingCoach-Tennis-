import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if !authService.isAuthenticated {
                SignInView()
            } else {
                MainTabView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
    }
}
