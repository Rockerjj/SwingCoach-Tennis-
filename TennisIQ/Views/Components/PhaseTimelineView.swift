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
                        connectingLine
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
                // Icon circle
                ZStack {
                    Circle()
                        .fill(isSelected ? DesignSystem.current.navBackground : theme.surfacePrimary)
                        .frame(width: isSelected ? 32 : 28, height: isSelected ? 32 : 28)

                    Circle()
                        .stroke(isSelected ? DesignSystem.current.navBackground : borderColor(status), lineWidth: 2)
                        .frame(width: isSelected ? 32 : 28, height: isSelected ? 32 : 28)

                    Image(systemName: phase.icon)
                        .font(.system(size: isSelected ? 13 : 11, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : theme.textSecondary)
                }
                .shadow(color: isSelected ? theme.textPrimary.opacity(0.15) : .clear, radius: 8, y: 2)

                // Score badge below circle
                Text("\(score)")
                    .font(AppFont.mono(size: 9, weight: .bold))
                    .foregroundStyle(isSelected ? .white : theme.textPrimary)

                // Full phase name
                Text(phase.displayName)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(isSelected ? .white : theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 50)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
    }

    private var connectingLine: some View {
        Rectangle()
            .fill(theme.surfaceSecondary)
            .frame(width: 16, height: 1.5)
    }

    private func borderColor(_ status: ZoneStatus) -> Color {
        switch status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }
}
