import SwiftUI

/// Hero insight card showing user's top 1-2 improvement priorities
/// Compact accordion: tap a row to expand freeze frame + detail
struct HeroInsightCard: View {
    let stroke: StrokeAnalysisModel
    var videoURL: URL?
    var poseFrames: [FramePoseData]
    private let theme = DesignSystem.current

    @State private var expandedPhase: SwingPhase? = nil

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
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                    Text("YOUR TOP PRIORITIES")
                        .font(AppFont.body(size: 10, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .tracking(1)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.sm)

                // Priority rows
                ForEach(Array(worstPhases.enumerated()), id: \.offset) { index, item in
                    priorityRow(index: index + 1, phase: item.0, detail: item.1)

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

    private func priorityRow(index: Int, phase: SwingPhase, detail: PhaseDetail) -> some View {
        let isExpanded = expandedPhase == phase

        return VStack(alignment: .leading, spacing: 0) {
            // Compact header row — always visible
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expandedPhase = isExpanded ? nil : phase
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text("\(index).")
                        .font(AppFont.body(size: 15, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 22, alignment: .leading)

                    Text(insightTitle(for: phase, detail: detail))
                        .font(AppFont.body(size: 14, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Score badge
                    Text("\(detail.score)/10")
                        .font(AppFont.mono(size: 11, weight: .bold))
                        .foregroundStyle(scoreColor(detail.score))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(scoreColor(detail.score).opacity(0.12))
                        )

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // Freeze frame with skeleton overlay
                    PhaseFrameCaptureView(
                        videoURL: videoURL,
                        timestamp: detail.timestamp,
                        poseFrames: poseFrames,
                        keyAngles: detail.keyAngles,
                        height: 160
                    )

                    // Detail text
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
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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
