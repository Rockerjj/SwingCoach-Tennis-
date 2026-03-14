import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .record

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
            // Full-screen background
            DesignSystem.current.background
                .ignoresSafeArea()

            // Content fills entire screen
            Group {
                switch selectedTab {
                case .record:
                    NavigationStack {
                        RecordView(switchToSessions: { selectedTab = .sessions })
                    }
                case .sessions:
                    SessionsListView()
                case .progress:
                    NavigationStack {
                        ProgressDashboardView()
                    }
                case .profile:
                    NavigationStack {
                        ProfileView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .top)

            // Custom compact tab bar pinned to bottom
            VStack(spacing: 0) {
                Color.white.opacity(0.1)
                    .frame(height: 0.5)

                HStack(spacing: 0) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(selectedTab == tab ? 1.0 : 0.4))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                        }
                    }
                }
            }
            .background(DesignSystem.current.navBackground)
            .padding(.bottom, safeAreaBottom)
            .background(DesignSystem.current.navBackground.ignoresSafeArea(edges: .bottom))
        }
        .ignoresSafeArea(.keyboard)
    }

    /// Bottom safe area inset for home indicator
    private var safeAreaBottom: CGFloat {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let window = scene.windows.first else { return 0 }
        return window.safeAreaInsets.bottom
    }
}
