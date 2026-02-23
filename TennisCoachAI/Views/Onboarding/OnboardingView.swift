import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    let theme = DesignSystem.current

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "video.fill",
            title: "Record Your Session",
            description: "Set up your iPhone on a tripod or lean it against the fence. Hit record and play your game.",
            accentColorKeyPath: \.accent
        ),
        OnboardingPage(
            icon: "figure.tennis",
            title: "AI Analyzes Your Form",
            description: "Our AI tracks your body movement, identifies each stroke, and evaluates your mechanics against professional technique.",
            accentColorKeyPath: \.accentSecondary
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Get Better, Fast",
            description: "Receive visual coaching overlays on your video, track your progress over time, and know exactly what to practice.",
            accentColorKeyPath: \.accent
        ),
    ]

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomControls
            }
        }
    }

    // MARK: - Page Content

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.08))
                    .frame(width: 160, height: 160)

                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(theme.accent)
            }

            VStack(spacing: Spacing.md) {
                Text(page.title)
                    .font(AppFont.display(size: 28))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(AppFont.body(size: 16))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Spacing.xl)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.xs) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? theme.accent : theme.textTertiary.opacity(0.3))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.25), value: currentPage)
                }
            }

            Button(action: advance) {
                Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                    .font(AppFont.body(size: 17, weight: .semibold))
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .padding(.horizontal, Spacing.lg)

            if currentPage < pages.count - 1 {
                Button("Skip") {
                    hasCompletedOnboarding = true
                }
                .font(AppFont.body(size: 15))
                .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.bottom, Spacing.xxl)
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation { currentPage += 1 }
        } else {
            hasCompletedOnboarding = true
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let accentColorKeyPath: KeyPath<any AppTheme, Color>
}
