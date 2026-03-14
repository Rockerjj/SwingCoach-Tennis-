import SwiftUI

struct LiveFeedbackOverlayView: View {
    let isActive: Bool
    let currentPhase: SwingPhase?
    let latestFeedback: LiveFeedbackEvent?
    let formGrade: String?

    private let theme = DesignSystem.current

    var body: some View {
        ZStack {
            if isActive {
                liveIndicator
                formQualityRing
                phasePips
            }

            if let feedback = latestFeedback, isActive {
                floatingCue(feedback)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .animation(.spring(response: 0.4), value: latestFeedback?.id)
    }

    private var liveIndicator: some View {
        HStack(spacing: Spacing.xxs) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
                .opacity(pulseOpacity)

            Text("LIVE")
                .font(AppFont.body(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs + 2)
        .background(.red.opacity(0.85))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Spacing.sm)
    }

    @State private var pulseOpacity: Double = 1.0

    private var formQualityRing: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(gradeColor.opacity(0.3), lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .stroke(gradeColor, lineWidth: 3)
                    .frame(width: 40, height: 40)

                Text(formGrade ?? "--")
                    .font(AppFont.display(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("FORM")
                .font(AppFont.body(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(Spacing.sm)
    }

    private func floatingCue(_ event: LiveFeedbackEvent) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 11, weight: .semibold))

            Text("\"\(event.cueText)\"")
                .font(AppFont.body(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(statusColor(event.severity).opacity(0.85))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 56)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var phasePips: some View {
        HStack(spacing: 4) {
            ForEach(SwingPhase.allCases, id: \.self) { phase in
                Circle()
                    .fill(pipColor(for: phase))
                    .frame(width: phase == currentPhase ? 10 : 8, height: phase == currentPhase ? 10 : 8)
                    .scaleEffect(phase == currentPhase ? 1.3 : 1.0)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs + 2)
        .background(.black.opacity(0.5))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, Spacing.sm)
    }

    private func pipColor(for phase: SwingPhase) -> Color {
        guard let current = currentPhase else { return .white.opacity(0.2) }
        if phase == current { return theme.accent }
        if phase.rawValue < current.rawValue { return theme.success }
        return .white.opacity(0.2)
    }

    private var gradeColor: Color {
        guard let grade = formGrade else { return .white.opacity(0.5) }
        if grade.hasPrefix("A") { return theme.success }
        if grade.hasPrefix("B") { return theme.success }
        if grade.hasPrefix("C") { return theme.warning }
        return theme.error
    }

    private func statusColor(_ status: ZoneStatus) -> Color {
        switch status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }
}
