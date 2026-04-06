import SwiftUI
import SwiftData

/// Shows bookmarked coaching insights — saved from CoachingCards
struct SavedInsightsView: View {
    @Query(sort: \BookmarkedInsight.createdAt, order: .reverse)
    private var insights: [BookmarkedInsight]
    @Environment(\.modelContext) private var modelContext

    let theme = DesignSystem.current

    var body: some View {
        if insights.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(insights) { insight in
                    SavedInsightCard(insight: insight, onDelete: { deleteInsight(insight) })
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "bookmark")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(theme.textTertiary)

            VStack(spacing: Spacing.xs) {
                Text("No Saved Insights")
                    .font(AppFont.body(size: 17, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Text("Tap the bookmark icon on any\ncoaching card to save it here")
                    .font(AppFont.body(size: 14))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxl)
    }

    private func deleteInsight(_ insight: BookmarkedInsight) {
        modelContext.delete(insight)
        try? modelContext.save()
    }
}

// MARK: - Saved Insight Card

struct SavedInsightCard: View {
    let insight: BookmarkedInsight
    let onDelete: () -> Void

    @State private var showAngleAnimation = false
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header: stroke type + grade + date + delete
            HStack {
                Image(systemName: insight.strokeType.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.accent)
                    .frame(width: 28, height: 28)
                    .background(theme.accentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                VStack(alignment: .leading, spacing: 1) {
                    Text(insight.strokeType.displayName)
                        .font(AppFont.body(size: 14, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    Text(insight.sessionDate, style: .date)
                        .font(AppFont.body(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                GradeBadge(grade: insight.grade)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Coaching text
            Text(insight.coachingText)
                .font(AppFont.body(size: 13))
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(3)
                .lineLimit(3)

            // Angle corrections preview (if joints available)
            if let joints = insight.jointSnapshot, !joints.isEmpty, !insight.keyAngles.isEmpty {
                let outOfRange = insight.keyAngles.compactMap { ParsedAngle.parse($0) }
                    .filter { $0.actual < $0.idealLow || $0.actual > $0.idealHigh }

                if !outOfRange.isEmpty {
                    Button(action: { withAnimation { showAngleAnimation.toggle() } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.tennis")
                                .font(.system(size: 11))
                            Text(showAngleAnimation ? "Hide Correction" : "Show Correction")
                                .font(AppFont.body(size: 12, weight: .medium))
                        }
                        .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)

                    if showAngleAnimation {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(outOfRange, id: \.jointName) { parsed in
                                    AngleCorrectionView(
                                        joints: joints,
                                        jointName: parsed.jointName,
                                        actualAngle: parsed.actual,
                                        idealAngle: parsed.idealMidpoint,
                                        label: parsed.jointName
                                    )
                                    .frame(width: 220)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }

            // User note (if any)
            if let note = insight.userNote, !note.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.accentSecondary)
                    Text(note)
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textSecondary)
                        .italic()
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }
}
