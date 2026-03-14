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
        VStack(spacing: 0) {
            // Content area
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

            // Custom compact tab bar
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
                .background(Color(hex: "0D2818"))
            }
            .background(Color(hex: "0D2818"))
        }
        .ignoresSafeArea(.keyboard)
        .background(Color(hex: "0D2818").ignoresSafeArea(edges: .bottom))
    }
}
