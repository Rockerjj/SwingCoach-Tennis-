import SwiftUI

/// Hero insight card showing user's top 1-2 improvement priorities
/// with freeze-frame skeleton overlays and impact badges
struct HeroInsightCard: View {
    let stroke: StrokeAnalysisModel
    var videoURL: URL?
    var poseFrames: [FramePoseData]
    private let theme = DesignSystem.current

    init(stroke: StrokeAnalysisModel, videoURL: URL? = nil, poseFrames: [FramePoseData] = []) {
        self.stroke = stroke
        self.videoURL = videoURL
        self.poseFrames = poseFrames
    }

    /// Derives the worst-scoring phases from the breakdown
    private var worstPhases: [(SwingPhase, PhaseDetail)] {
        guard let breakdown = stroke.phaseBreakdown else { return [] }
        let filtered = breakdown.allPhases
            .compactMap { (phase, detail) -> (SwingPhase, PhaseDetail)? in
                guard let d = detail, d.status != .inZone else { return nil }
                return (phase, d)
            }
            .sorted { $0.1.score < $1.1.score }
        return Array(filtered.prefix(2))
    }

    var body: some View {
        if worstPhases.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                    Text("YOUR TOP PRIORITIES")
                        .font(AppFont.body(size: 10, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .tracking(1)
                }

                ForEach(Array(worstPhases.enumerated()), id: \.offset) { _, item in
                    insightRow(phase: item.0, detail: item.1)
                }
            }
            .padding(Spacing.md)
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
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
    }

    private func insightRow(phase: SwingPhase, detail: PhaseDetail) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Freeze frame with skeleton overlay
            PhaseFrameCaptureView(
                videoURL: videoURL,
                timestamp: detail.timestamp,
                poseFrames: poseFrames,
                keyAngles: detail.keyAngles,
                height: 160
            )

            // Bold insight title
            Text(insightTitle(for: phase, detail: detail))
                .font(AppFont.body(size: 15, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            // Specific detail
            Text(detail.improveCue ?? detail.note)
                .font(AppFont.body(size: 13))
                .foregroundStyle(theme.textTertiary)
                .lineSpacing(2)

            // Impact pill
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
                Text("HIGH IMPACT")
                    .font(AppFont.body(size: 10, weight: .bold))
                    .foregroundStyle(theme.textSecondary)
                    .tracking(0.5)
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(theme.surfaceSecondary)
            )
        }
    }

    private func insightTitle(for phase: SwingPhase, detail: PhaseDetail) -> String {
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
