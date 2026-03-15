import SwiftUI

/// Horizontal pill bar for jumping between analysis sections
struct SectionJumpBar: View {
    @Binding var activeTab: SectionTab
    var onTap: ((SectionTab) -> Void)? = nil
    private let theme = DesignSystem.current

    enum SectionTab: String, CaseIterable {
        case overview = "Overview"
        case phases = "Phases"
        case coaching = "Coaching"
        case drills = "Drills"
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SectionTab.allCases, id: \.self) { tab in
                    let isActive = activeTab == tab
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeTab = tab
                        }
                        onTap?(tab)
                    } label: {
                        Text(tab.rawValue)
                            .font(AppFont.body(size: 12, weight: .semibold))
                            .foregroundStyle(isActive ? theme.textPrimary : theme.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isActive ? theme.surfaceSecondary : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
        }
        .background(theme.background)
    }
}
