import SwiftUI

/// Hero insight card showing user's top 1-2 improvement priorities
/// with visual correction diagrams and impact badges
struct HeroInsightCard: View {
    let stroke: StrokeAnalysisModel
    private let theme = DesignSystem.current

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
                        .foregroundStyle(theme.accent)
                    Text("YOUR TOP PRIORITIES")
                        .font(AppFont.body(size: 10, weight: .bold))
                        .foregroundStyle(theme.accent)
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
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
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
            // Visual placeholder area
            AngleCorrectionDiagram(
                phase: phase,
                detail: detail,
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
                    .foregroundStyle(theme.accent)
                Text("HIGH IMPACT")
                    .font(AppFont.body(size: 10, weight: .bold))
                    .foregroundStyle(theme.accent)
                    .tracking(0.5)
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(theme.accentMuted)
            )
        }
    }

    private func insightTitle(for phase: SwingPhase, detail: PhaseDetail) -> String {
        // Generate a direct, actionable title from phase + detail
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

// MARK: - Angle Correction Diagram

/// Draws a simple visual showing current vs ideal angle for a phase
struct AngleCorrectionDiagram: View {
    let phase: SwingPhase
    let detail: PhaseDetail
    var height: CGFloat = 140
    private let theme = DesignSystem.current

    /// Parse angle info from keyAngles
    private var angleInfo: (current: Int, idealLow: Int, idealHigh: Int)? {
        // Try to parse something like "Elbow: 142° (ideal: 90-110°)"
        for angle in detail.keyAngles {
            let parts = angle.components(separatedBy: ":")
            guard parts.count >= 2 else { continue }
            let valuePart = parts[1]
            // Extract current angle
            if let range = valuePart.range(of: #"\d+"#, options: .regularExpression) {
                let current = Int(valuePart[range]) ?? 0
                // Try to find ideal range
                if let idealRange = valuePart.range(of: #"(\d+)-(\d+)"#, options: .regularExpression) {
                    let idealStr = String(valuePart[idealRange])
                    let idealParts = idealStr.components(separatedBy: "-")
                    if idealParts.count == 2,
                       let lo = Int(idealParts[0]),
                       let hi = Int(idealParts[1]) {
                        return (current, lo, hi)
                    }
                }
                return (current, 0, 0)
            }
        }
        return nil
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(theme.surfaceSecondary)

            Canvas { context, size in
                drawCorrectionDiagram(context: context, size: size)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }

    private func drawCorrectionDiagram(context: GraphicsContext, size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height * 0.55

        // Draw a simplified stick figure torso + arm
        let shoulderPt = CGPoint(x: centerX, y: centerY - 20)
        let hipPt = CGPoint(x: centerX, y: centerY + 30)
        let headPt = CGPoint(x: centerX, y: centerY - 45)

        // Body color
        let bodyColor = Color(hex: "1B4332")

        // Head
        let headRect = CGRect(x: headPt.x - 8, y: headPt.y - 8, width: 16, height: 16)
        context.stroke(Path(ellipseIn: headRect), with: .color(bodyColor), lineWidth: 1.8)

        // Spine
        var spine = Path()
        spine.move(to: CGPoint(x: centerX, y: headPt.y + 8))
        spine.addLine(to: hipPt)
        context.stroke(spine, with: .color(bodyColor), lineWidth: 2)

        // Shoulders
        let lShoulder = CGPoint(x: centerX - 18, y: shoulderPt.y)
        let rShoulder = CGPoint(x: centerX + 18, y: shoulderPt.y)
        var shoulders = Path()
        shoulders.move(to: lShoulder)
        shoulders.addLine(to: rShoulder)
        context.stroke(shoulders, with: .color(bodyColor), lineWidth: 1.8)

        // Left arm (non-racket)
        var leftArm = Path()
        leftArm.move(to: lShoulder)
        leftArm.addLine(to: CGPoint(x: centerX - 30, y: shoulderPt.y + 20))
        context.stroke(leftArm, with: .color(bodyColor), lineWidth: 1.8)

        // Current arm (dashed, warning color)
        let currentElbow = CGPoint(x: centerX + 38, y: shoulderPt.y - 16)
        let currentWrist = CGPoint(x: centerX + 55, y: shoulderPt.y - 32)

        var currentArm = Path()
        currentArm.move(to: rShoulder)
        currentArm.addLine(to: currentElbow)
        currentArm.addLine(to: currentWrist)
        context.stroke(
            currentArm,
            with: .color(Color(hex: "D97706")),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 2])
        )

        // Ideal arm (solid, green)
        let idealElbow = CGPoint(x: centerX + 32, y: shoulderPt.y - 22)
        let idealWrist = CGPoint(x: centerX + 30, y: shoulderPt.y - 42)

        var idealArm = Path()
        idealArm.move(to: rShoulder)
        idealArm.addLine(to: idealElbow)
        idealArm.addLine(to: idealWrist)
        context.stroke(
            idealArm,
            with: .color(Color(hex: "16A34A")),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )

        // Legs
        let lHip = CGPoint(x: centerX - 10, y: hipPt.y)
        let rHip = CGPoint(x: centerX + 10, y: hipPt.y)
        var hips = Path()
        hips.move(to: lHip)
        hips.addLine(to: rHip)
        context.stroke(hips, with: .color(bodyColor), lineWidth: 1.8)

        var leftLeg = Path()
        leftLeg.move(to: lHip)
        leftLeg.addLine(to: CGPoint(x: centerX - 15, y: hipPt.y + 30))
        leftLeg.addLine(to: CGPoint(x: centerX - 18, y: hipPt.y + 55))
        context.stroke(leftLeg, with: .color(bodyColor), lineWidth: 1.8)

        var rightLeg = Path()
        rightLeg.move(to: rHip)
        rightLeg.addLine(to: CGPoint(x: centerX + 15, y: hipPt.y + 30))
        rightLeg.addLine(to: CGPoint(x: centerX + 18, y: hipPt.y + 55))
        context.stroke(rightLeg, with: .color(bodyColor), lineWidth: 1.8)

        // Labels
        if let info = angleInfo, info.idealHigh > 0 {
            // "You: XXX°" label near current arm
            context.draw(
                Text("You: \(info.current)\u{00B0}")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(hex: "D97706")),
                at: CGPoint(x: currentWrist.x + 10, y: currentWrist.y + 14)
            )

            // "Ideal: XX-XX°" label near ideal arm
            context.draw(
                Text("Ideal: \(info.idealLow)-\(info.idealHigh)\u{00B0}")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(hex: "16A34A")),
                at: CGPoint(x: idealWrist.x - 30, y: idealWrist.y - 4)
            )
        } else {
            // Phase name + "Tap to view"
            context.draw(
                Text(phase.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "6B7280")),
                at: CGPoint(x: size.width / 2, y: size.height / 2 - 10)
            )
            context.draw(
                Text("Tap to view")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "9CA3AF")),
                at: CGPoint(x: size.width / 2, y: size.height / 2 + 10)
            )
        }

        // Legend
        let legendY = size.height - 14
        // Current legend
        var currentLine = Path()
        currentLine.move(to: CGPoint(x: size.width - 100, y: legendY))
        currentLine.addLine(to: CGPoint(x: size.width - 80, y: legendY))
        context.stroke(
            currentLine,
            with: .color(Color(hex: "D97706")),
            style: StrokeStyle(lineWidth: 2, dash: [4, 2])
        )
        context.draw(
            Text("Current").font(.system(size: 8)).foregroundColor(Color(hex: "D97706")),
            at: CGPoint(x: size.width - 62, y: legendY)
        )

        // Ideal legend
        var idealLine = Path()
        idealLine.move(to: CGPoint(x: size.width - 100, y: legendY - 14))
        idealLine.addLine(to: CGPoint(x: size.width - 80, y: legendY - 14))
        context.stroke(idealLine, with: .color(Color(hex: "16A34A")), lineWidth: 2)
        context.draw(
            Text("Ideal").font(.system(size: 8)).foregroundColor(Color(hex: "16A34A")),
            at: CGPoint(x: size.width - 66, y: legendY - 14)
        )
    }
}
