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
        TabView(selection: $selectedTab) {
            RecordView(switchToSessions: { selectedTab = .sessions })
                .tag(Tab.record)
                .tabItem {
                    Label(Tab.record.rawValue, systemImage: Tab.record.icon)
                }

            SessionsListView()
                .tag(Tab.sessions)
                .tabItem {
                    Label(Tab.sessions.rawValue, systemImage: Tab.sessions.icon)
                }

            ProgressDashboardView()
                .tag(Tab.progress)
                .tabItem {
                    Label(Tab.progress.rawValue, systemImage: Tab.progress.icon)
                }

            ProfileView()
                .tag(Tab.profile)
                .tabItem {
                    Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
                }
        }
        .tint(.white)
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor(Color(hex: "1B4332"))

            // Compact layout
            let itemAppearance = UITabBarItemAppearance(style: .compactInline)
            itemAppearance.normal.iconColor = UIColor.gray
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray, .font: UIFont.systemFont(ofSize: 10)]
            itemAppearance.selected.iconColor = UIColor.white
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 10)]

            let stackedAppearance = UITabBarItemAppearance(style: .stacked)
            stackedAppearance.normal.iconColor = UIColor.gray
            stackedAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray, .font: UIFont.systemFont(ofSize: 10)]
            stackedAppearance.selected.iconColor = UIColor.white
            stackedAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 10)]

            tabBarAppearance.stackedLayoutAppearance = stackedAppearance
            tabBarAppearance.compactInlineLayoutAppearance = itemAppearance
            tabBarAppearance.inlineLayoutAppearance = itemAppearance

            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        .background(
            Color(hex: "1A1A1A").ignoresSafeArea()
        )
    }
}
