import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showLaunch = true

    var body: some View {
        ZStack {
            if showLaunch {
                LaunchView()
                    .transition(.opacity)
                    .zIndex(1)
            } else if !hasCompletedOnboarding {
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
        .animation(.easeInOut(duration: 0.4), value: showLaunch)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                showLaunch = false
            }
        }
    }
}
