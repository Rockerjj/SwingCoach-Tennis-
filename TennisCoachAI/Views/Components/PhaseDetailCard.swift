import SwiftUI

struct PhaseDetailCard: View {
    let phase: SwingPhase
    let detail: PhaseDetail?

    @State private var isExpanded = true
    private let theme = DesignSystem.current

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
                        .font(AppFont.body(size: 15, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    if let d = detail {
                        Text(String(format: "@ %.1fs", d.timestamp))
                            .font(AppFont.mono(size: 12))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                Spacer()

                if let d = detail {
                    ZStack {
                        Circle()
                            .stroke(theme.surfaceSecondary, lineWidth: 3)
                            .frame(width: 40, height: 40)
                        Circle()
                            .trim(from: 0, to: CGFloat(d.score) / 10)
                            .stroke(scoreColor(d.score), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                        Text("\(d.score)")
                            .font(AppFont.mono(size: 12, weight: .bold))
                            .foregroundStyle(theme.textPrimary)
                    }
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

    private func expandedContent(detail: PhaseDetail) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Divider().foregroundStyle(theme.surfaceSecondary)

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
                    Rectangle()
                        .fill(theme.accent)
                        .frame(width: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Coaching Cue")
                            .font(AppFont.body(size: 11, weight: .semibold))
                            .foregroundStyle(theme.accent)
                        Text(cue)
                            .font(AppFont.body(size: 13))
                            .foregroundStyle(theme.textPrimary)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(theme.accentMuted.opacity(0.5))
                )
            }

            if let drill = detail.drill, !drill.isEmpty {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.accentSecondary)

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
        case 5...7: return theme.accent
        case 3...4: return theme.warning
        default: return theme.error
        }
    }
}
