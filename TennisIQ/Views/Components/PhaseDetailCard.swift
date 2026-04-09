import SwiftUI

struct PhaseDetailCard: View {
    let phase: SwingPhase
    let detail: PhaseDetail?
    var videoURL: URL?
    var poseFrames: [FramePoseData]

    @State private var isExpanded = true
    private let theme = DesignSystem.current

    init(phase: SwingPhase, detail: PhaseDetail?, videoURL: URL? = nil, poseFrames: [FramePoseData] = []) {
        self.phase = phase
        self.detail = detail
        self.videoURL = videoURL
        self.poseFrames = poseFrames
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded, let d = detail {
                expandedContent(detail: d)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(theme.surfaceSecondary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }

    private var header: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: phase.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36)
                    .background(theme.accentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(phase.displayName)
                        .font(AppFont.body(size: 16, weight: .bold))
                        .foregroundStyle(theme.textPrimary)

                    if let d = detail {
                        Text(String(format: "@ %.2fs", d.timestamp))
                            .font(AppFont.mono(size: 11))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                Spacer()

                if let d = detail {
                    scoreCircle(d)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(Spacing.md)
        }
        .buttonStyle(.plain)
    }

    private func scoreCircle(_ d: PhaseDetail) -> some View {
        ZStack {
            Circle()
                .fill(scoreColor(d.score).opacity(0.08))
                .frame(width: 36, height: 36)
            Text("\(d.score)")
                .font(AppFont.mono(size: 14, weight: .bold))
                .foregroundStyle(scoreColor(d.score))
        }
    }

    private func expandedContent(detail: PhaseDetail) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Divider().foregroundStyle(theme.surfaceSecondary)

            // Freeze frame with skeleton overlay
            PhaseFrameCaptureView(
                videoURL: videoURL,
                timestamp: detail.timestamp,
                poseFrames: poseFrames,
                keyAngles: detail.keyAngles,
                height: 300
            )

            if !detail.keyAngles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(detail.keyAngles, id: \.self) { angle in
                            Text(angle)
                                .font(AppFont.mono(size: 11))
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xxs)
                                .background(Capsule().fill(theme.accentMuted))
                        }
                    }
                }
            }

            if !detail.note.isEmpty {
                Text(detail.note)
                    .font(AppFont.body(size: 13))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
            }

            if let cue = detail.improveCue, !cue.isEmpty {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.accent)
                        .padding(.top, 1)

                    Text(cue)
                        .font(AppFont.body(size: 13))
                        .foregroundStyle(theme.textPrimary)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(theme.accentMuted)
                )
            }

            if let drill = detail.drill, !drill.isEmpty {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.accent)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Practice Drill")
                            .font(AppFont.body(size: 11, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                        Text(drill)
                            .font(AppFont.body(size: 13))
                            .foregroundStyle(theme.textPrimary)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(theme.surfaceSecondary)
                )
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 8...10: return theme.success
        case 5...7: return theme.warning
        case 3...4: return theme.error
        default: return theme.error
        }
    }
}
