import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @AppStorage("selectedTheme") private var selectedTheme = "Court Vision"
    @State private var selectedSkillLevel: SkillLevel = .beginner
    let theme = DesignSystem.current

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        profileHeader
                        subscriptionCard
                        settingsSection
                        themeSection
                        legalSection
                        signOutButton
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle("Profile")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.1))
                    .frame(width: 80, height: 80)

                Text(initials)
                    .font(AppFont.display(size: 28))
                    .foregroundStyle(theme.accent)
            }

            Text(authService.displayName ?? "Tennis Player")
                .font(AppFont.display(size: 20))
                .foregroundStyle(theme.textPrimary)

            Text(selectedSkillLevel.displayName)
                .font(AppFont.body(size: 14))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    // MARK: - Subscription Card

    private var subscriptionCard: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Current Plan")
                        .font(AppFont.body(size: 13))
                        .foregroundStyle(theme.textSecondary)

                    Text(subscriptionService.currentTier.displayName)
                        .font(AppFont.display(size: 18))
                        .foregroundStyle(theme.textPrimary)
                }

                Spacer()

                if subscriptionService.currentTier == .free {
                    Button(action: {}) {
                        Text("Upgrade")
                            .font(AppFont.body(size: 14, weight: .semibold))
                            .foregroundStyle(theme.textOnAccent)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(theme.accent)
                            .clipShape(Capsule())
                    }
                }
            }

            if subscriptionService.currentTier == .free {
                let remaining = AppConstants.Analysis.freeSessionsAllowed - subscriptionService.freeAnalysesUsed
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(theme.accent)
                        .font(.system(size: 14))

                    Text("\(remaining) free analyses remaining")
                        .font(AppFont.body(size: 13))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SKILL LEVEL")
                .font(AppFont.body(size: 12, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    Button(action: { selectedSkillLevel = level }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.displayName)
                                    .font(AppFont.body(size: 15, weight: .medium))
                                    .foregroundStyle(theme.textPrimary)

                                Text(level.description)
                                    .font(AppFont.body(size: 12))
                                    .foregroundStyle(theme.textTertiary)
                            }

                            Spacer()

                            if selectedSkillLevel == level {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.accent)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .padding(Spacing.md)
                    }
                    .buttonStyle(.plain)

                    if level != SkillLevel.allCases.last {
                        Divider()
                            .background(theme.surfaceSecondary)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.surfacePrimary)
            )
        }
    }

    // MARK: - Theme Selector

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("DESIGN THEME")
                .font(AppFont.body(size: 12, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                themeOption("Court Vision", theme: CourtVisionTheme())
                Divider().background(theme.surfaceSecondary)
                themeOption("Grand Slam", theme: GrandSlamTheme())
                Divider().background(theme.surfaceSecondary)
                themeOption("Rally", theme: RallyTheme())
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.surfacePrimary)
            )
        }
    }

    private func themeOption(_ name: String, theme appTheme: AppTheme) -> some View {
        Button(action: {
            selectedTheme = name
            DesignSystem.shared.setTheme(appTheme)
        }) {
            HStack(spacing: Spacing.sm) {
                HStack(spacing: 4) {
                    Circle().fill(appTheme.accent).frame(width: 16, height: 16)
                    Circle().fill(appTheme.accentSecondary).frame(width: 16, height: 16)
                    Circle().fill(appTheme.background).frame(width: 16, height: 16)
                        .overlay(Circle().stroke(theme.textTertiary.opacity(0.3), lineWidth: 1))
                }

                Text(name)
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                if selectedTheme == name {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .padding(Spacing.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("LEGAL")
                .font(AppFont.body(size: 12, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                legalLink("Privacy Policy", url: AppConstants.privacyPolicyURL)
                Divider().background(theme.surfaceSecondary)
                legalLink("Terms of Service", url: AppConstants.termsOfServiceURL)
                Divider().background(theme.surfaceSecondary)
                legalLink("Contact Support", url: URL(string: "mailto:\(AppConstants.supportEmail)")!)
                Divider().background(theme.surfaceSecondary)
                legalLink("Chat with the Founder", url: URL(string: "mailto:\(AppConstants.supportEmail)?subject=App%20Feedback")!)
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.surfacePrimary)
            )
        }
    }

    private func legalLink(_ title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(title)
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button(action: { authService.signOut() }) {
            Text("Sign Out")
                .font(AppFont.body(size: 15, weight: .medium))
                .foregroundStyle(theme.error)
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(theme.surfacePrimary)
                )
        }
    }

    private var initials: String {
        let name = authService.displayName ?? "TP"
        let parts = name.split(separator: " ")
        let first = parts.first.map { String($0.prefix(1)).uppercased() } ?? "T"
        let last = parts.count > 1 ? String(parts.last!.prefix(1)).uppercased() : "P"
        return first + last
    }
}
