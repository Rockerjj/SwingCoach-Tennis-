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
        .tint(DesignSystem.current.accent)
    }
}
