import SwiftUI

/// Compact card showing 1-3 ranked fix items, replacing HeroInsightCard + VideoFocusInsightCard
struct KeyFixesCard: View {
    let stroke: StrokeAnalysisModel
    @Binding var selectedPhase: SwingPhase?
    var onScrollToPhases: (() -> Void)? = nil
    private let theme = DesignSystem.current

    /// Derives the worst-scoring phases from the breakdown (up to 3)
    private var worstPhases: [(SwingPhase, PhaseDetail)] {
        guard let breakdown = stroke.phaseBreakdown else { return [] }
        let filtered = breakdown.allPhases
            .compactMap { (phase, detail) -> (SwingPhase, PhaseDetail)? in
                guard let d = detail, d.status != .inZone else { return nil }
                return (phase, d)
            }
            .sorted { $0.1.score < $1.1.score }
        return Array(filtered.prefix(3))
    }

    var body: some View {
        if worstPhases.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.accent)
                    Text("KEY FIXES")
                        .font(AppFont.body(size: 10, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .tracking(1)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.sm)

                // Fix rows
                ForEach(Array(worstPhases.enumerated()), id: \.offset) { index, item in
                    fixRow(index: index + 1, phase: item.0, detail: item.1)

                    if index < worstPhases.count - 1 {
                        Divider()
                            .foregroundStyle(theme.surfaceSecondary)
                            .padding(.horizontal, Spacing.md)
                    }
                }

                Spacer().frame(height: Spacing.sm)
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(theme.surfaceSecondary, lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                UnevenRoundedRectangle(
                    topLeadingRadius: Radius.md,
                    bottomLeadingRadius: Radius.md,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(theme.accent)
                .frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
    }

    private func fixRow(index: Int, phase: SwingPhase, detail: PhaseDetail) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedPhase = phase
            }
            onScrollToPhases?()
        } label: {
            HStack(spacing: Spacing.sm) {
                // Numbered index
                Text("\(index)")
                    .font(AppFont.body(size: 14, weight: .bold))
                    .foregroundStyle(theme.textOnAccent)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(theme.accent))

                // Phase icon
                Image(systemName: phase.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 28, height: 28)
                    .background(theme.accentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                // One-line coaching cue
                Text(insightTitle(for: phase, detail: detail))
                    .font(AppFont.body(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)

                Spacer()

                // Severity badge
                Text("\(detail.score)/10")
                    .font(AppFont.mono(size: 11, weight: .bold))
                    .foregroundStyle(scoreColor(detail.score))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(scoreColor(detail.score).opacity(0.12))
                    )
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 8...10: return theme.success
        case 5...7: return theme.accent
        case 3...4: return theme.warning
        default: return theme.error
        }
    }

    private func insightTitle(for phase: SwingPhase, detail: PhaseDetail) -> String {
        if let cue = detail.improveCue, !cue.isEmpty { return cue }
        switch phase {
        case .readyPosition: return "Set your feet earlier"
        case .unitTurn: return "Rotate your hips more"
        case .backswing: return "Loop the racket higher on take-back"
        case .forwardSwing: return "Accelerate through the swing"
        case .contactPoint: return "Meet the ball further forward"
        case .followThrough: return "Extend over your shoulder"
        case .recovery: return "Get back to ready position faster"
        }
    }
}
