import SwiftUI

struct PhaseTimelineView: View {
    let breakdown: PhaseBreakdown
    @Binding var selectedPhase: SwingPhase?
    let onPhaseSelected: (SwingPhase) -> Void

    private let theme = DesignSystem.current

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(breakdown.allPhases.enumerated()), id: \.offset) { index, item in
                    let (phase, detail) = item
                    phaseNode(phase: phase, detail: detail)
                    if index < breakdown.allPhases.count - 1 {
                        connectingLine(status: detail?.status ?? .warning)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func phaseNode(phase: SwingPhase, detail: PhaseDetail?) -> some View {
        let isSelected = selectedPhase == phase
        let score = detail?.score ?? 0
        let status = detail?.status ?? .warning

        return Button(action: {
            selectedPhase = phase
            onPhaseSelected(phase)
        }) {
            VStack(spacing: Spacing.xxs) {
                ZStack {
                    Circle()
                        .fill(zoneColor(status))
                        .frame(width: 36, height: 36)

                    Text("\(score)")
                        .font(AppFont.mono(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? theme.accent : .clear, lineWidth: 2.5)
                        .frame(width: 42, height: 42)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)

                Text(phase.displayName)
                    .font(AppFont.body(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 52)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
    }

    private func connectingLine(status: ZoneStatus) -> some View {
        Rectangle()
            .fill(zoneColor(status).opacity(0.5))
            .frame(width: 16, height: 2)
    }

    private func zoneColor(_ status: ZoneStatus) -> Color {
        switch status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }
}
