import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .sessions
    private let theme = DesignSystem.current

    enum Tab: String, CaseIterable {
        case record = "Record"
        case sessions = "Sessions"
        case progress = "Progress"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .record: return "video.fill"
            case .sessions: return "list.bullet.rectangle.fill"
            case .progress: return "chart.line.uptrend.xyaxis"
            case .profile: return "person.fill"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.background
                .ignoresSafeArea()

            currentTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            compactTabBar
        }
    }

    @ViewBuilder
    private var currentTabContent: some View {
        switch selectedTab {
        case .record:
            tabNavigationContainer {
                RecordView(switchToSessions: { selectedTab = .sessions })
            }
        case .sessions:
            tabNavigationContainer {
                SessionsListView()
            }
        case .progress:
            tabNavigationContainer {
                ProgressDashboardView()
            }
        case .profile:
            tabNavigationContainer {
                ProfileView()
            }
        }
    }

    private func tabNavigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(theme.background)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.background)
    }

    private var compactTabBar: some View {
        VStack(spacing: 0) {
            theme.surfaceSecondary.opacity(0.8)
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(selectedTab == tab ? theme.textPrimary : theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.xs)
            .padding(.bottom, max(Spacing.sm, 12))
        }
        .background(theme.navBackground.ignoresSafeArea(edges: .bottom))
    }
}
