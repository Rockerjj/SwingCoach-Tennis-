import SwiftUI

// MARK: - Angle Correction Animation View
// Shows a skeleton overlay from real pose data, displays the actual angle with a bubble,
// then smoothly morphs to the ideal angle so the user can visualize the correction.

struct AngleCorrectionView: View {
    /// The joints from the actual video frame (FramePoseData.joints)
    let joints: [JointData]
    /// The joint being corrected (e.g., "elbow", "knee", "shoulder_rotation")
    let jointName: String
    /// The actual measured angle in degrees
    let actualAngle: Double
    /// The ideal target angle in degrees (midpoint of ideal range)
    let idealAngle: Double
    /// Display label (e.g. "Elbow")
    let label: String

    @State private var animationProgress: Double = 0
    @State private var hasStarted = false
    @State private var showingIdeal = false

    let theme = DesignSystem.current

    // Bone connections matching OverlayRenderer
    private static let bones: [(String, String)] = [
        ("left_shoulder", "right_shoulder"),
        ("left_shoulder", "left_elbow"),
        ("left_elbow", "left_wrist"),
        ("right_shoulder", "right_elbow"),
        ("right_elbow", "right_wrist"),
        ("left_shoulder", "left_hip"),
        ("right_shoulder", "right_hip"),
        ("left_hip", "right_hip"),
        ("left_hip", "left_knee"),
        ("left_knee", "left_ankle"),
        ("right_hip", "right_knee"),
        ("right_knee", "right_ankle"),
        ("nose", "left_shoulder"),
        ("nose", "right_shoulder"),
    ]

    /// The 3-joint chain for the angle being visualized
    private var angleChain: (a: String, b: String, c: String)? {
        let side = Handedness.current == .right ? "right" : "left"
        let lower = jointName.lowercased()

        if lower.contains("elbow") {
            return ("\(side)_shoulder", "\(side)_elbow", "\(side)_wrist")
        } else if lower.contains("knee") {
            return ("\(side)_hip", "\(side)_knee", "\(side)_ankle")
        } else if lower.contains("hip") && !lower.contains("rotation") {
            return ("\(side)_shoulder", "\(side)_hip", "\(side)_knee")
        } else if lower.contains("arm") || lower.contains("extension") {
            return ("\(side)_shoulder", "\(side)_elbow", "\(side)_wrist")
        } else if lower.contains("shoulder") && lower.contains("rotation") {
            // Shoulder rotation — pivot the shoulder line
            return ("left_shoulder", "right_shoulder", "left_hip")
        } else if lower.contains("hip") && lower.contains("lead") {
            return ("left_hip", "right_hip", "left_shoulder")
        } else if lower.contains("wrist") {
            return ("\(side)_elbow", "\(side)_wrist", "\(side)_shoulder")
        }

        return nil
    }

    /// Current display angle (interpolated between actual and ideal)
    /// Clamped to 0-360 to prevent nonsensical negative values from display
    private var displayAngle: Double {
        let raw = actualAngle + (idealAngle - actualAngle) * animationProgress
        return max(0, min(360, raw))
    }

    /// Sanitized actual angle — clamp negative/impossible values
    private var sanitizedActualAngle: Double {
        max(0, min(360, actualAngle))
    }

    /// Sanitized ideal angle
    private var sanitizedIdealAngle: Double {
        max(0, min(360, idealAngle))
    }

    /// Build the interpolated joint positions
    private func interpolatedJoints() -> [String: CGPoint] {
        var map: [String: CGPoint] = [:]
        for j in joints {
            map[j.name] = CGPoint(x: j.x, y: j.y)
        }

        // Rotate the end joint (c) around the pivot (b) to morph toward ideal angle
        guard let chain = angleChain,
              let a = map[chain.a], let b = map[chain.b], let c = map[chain.c] else {
            return map
        }

        // Calculate how much to rotate c around b
        let angleDiff = idealAngle - actualAngle
        let rotationRadians = (angleDiff * animationProgress) * .pi / 180.0

        // Rotate point c around point b
        let dx = c.x - b.x
        let dy = c.y - b.y
        let cosR = cos(rotationRadians)
        let sinR = sin(rotationRadians)
        let newX = b.x + dx * cosR - dy * sinR
        let newY = b.y + dx * sinR + dy * cosR

        map[chain.c] = CGPoint(x: newX, y: newY)
        return map
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            // Canvas for skeleton + angle visualization
            Canvas { context, size in
                drawSkeletonWithAngle(context: context, size: size)
            }
            .frame(height: 200)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Color.black.opacity(0.85))
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .onAppear {
                // Auto-play: show actual for 1s, then animate to ideal over 1.5s
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    hasStarted = true
                    withAnimation(.easeInOut(duration: 1.5)) {
                        animationProgress = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showingIdeal = true
                        // Pause, then loop back
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeInOut(duration: 1.2)) {
                                animationProgress = 0.0
                                showingIdeal = false
                            }
                            // Re-trigger the forward animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeInOut(duration: 1.5)) {
                                    animationProgress = 1.0
                                }
                            }
                        }
                    }
                }
            }

            // Label row
            HStack(spacing: Spacing.sm) {
                // Actual angle badge — use sanitized value (clamp negatives)
                AngleBadge(
                    label: "Your \(label)",
                    angle: sanitizedActualAngle,
                    color: angleDiffSeverityColor(actual: sanitizedActualAngle, ideal: sanitizedIdealAngle),
                    isActive: animationProgress < 0.5
                )

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.textTertiary)

                // Ideal angle badge
                AngleBadge(
                    label: "Ideal \(label)",
                    angle: sanitizedIdealAngle,
                    color: theme.success,
                    isActive: animationProgress >= 0.5
                )
            }
        }
    }

    // MARK: - Drawing

    private func drawSkeletonWithAngle(context: GraphicsContext, size: CGSize) {
        let jointMap = interpolatedJoints()

        func pt(_ name: String) -> CGPoint? {
            guard let n = jointMap[name] else { return nil }
            return CGPoint(x: n.x * size.width, y: (1.0 - n.y) * size.height)
        }

        let defaultColor = Color.white.opacity(0.4)
        let highlightColor = Color(red: 0.83, green: 0.58, blue: 0.16) // clay/gold
        let correctionColor = animationProgress > 0.5
            ? Color(red: 0.2, green: 0.8, blue: 0.4) // green for ideal
            : highlightColor

        let highlightedJoints: Set<String> = {
            guard let chain = angleChain else { return [] }
            return [chain.a, chain.b, chain.c]
        }()

        // Draw bones
        for (a, b) in Self.bones {
            guard let pa = pt(a), let pb = pt(b) else { continue }
            let isHighlighted = highlightedJoints.contains(a) || highlightedJoints.contains(b)
            var path = Path()
            path.move(to: pa)
            path.addLine(to: pb)

            if isHighlighted {
                // Glow
                context.stroke(path,
                    with: .color(correctionColor.opacity(0.35)),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round))
                // Core
                context.stroke(path,
                    with: .color(correctionColor),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
            } else {
                context.stroke(path,
                    with: .color(defaultColor),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }

        // Draw joints
        for (name, _) in jointMap {
            guard let p = pt(name) else { continue }
            let isHighlighted = highlightedJoints.contains(name)
            let radius: CGFloat = isHighlighted ? 5 : 3
            let color = isHighlighted ? correctionColor : defaultColor
            let dotRect = CGRect(x: p.x - radius, y: p.y - radius,
                                 width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: dotRect), with: .color(color))
        }

        // Draw angle arc + bubble at pivot joint
        if let chain = angleChain, let pivot = pt(chain.b) {
            // Draw angle arc
            if let pa = pt(chain.a), let pc = pt(chain.c) {
                let startAngle = atan2(pa.y - pivot.y, pa.x - pivot.x)
                let endAngle = atan2(pc.y - pivot.y, pc.x - pivot.x)

                var arcPath = Path()
                arcPath.addArc(center: pivot, radius: 25,
                               startAngle: .radians(startAngle),
                               endAngle: .radians(endAngle),
                               clockwise: false)
                context.stroke(arcPath,
                    with: .color(correctionColor.opacity(0.7)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }

            // Angle bubble
            let bubbleCenter = CGPoint(x: pivot.x + 35, y: pivot.y - 25)
            let displayStr = "\(Int(displayAngle))°"
            let bubbleRect = CGRect(x: bubbleCenter.x - 22, y: bubbleCenter.y - 12,
                                    width: 44, height: 24)

            let bubblePath = Path(roundedRect: bubbleRect, cornerRadius: 8)
            context.fill(bubblePath, with: .color(correctionColor.opacity(0.85)))

            context.draw(
                Text(displayStr)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white),
                at: bubbleCenter
            )
        }
    }

    private func angleDiffSeverityColor(actual: Double, ideal: Double) -> Color {
        let diff = abs(actual - ideal)
        if diff < 10 { return theme.success }
        if diff < 25 { return theme.warning }
        return theme.error
    }
}

// MARK: - Angle Badge

private struct AngleBadge: View {
    let label: String
    let angle: Double
    let color: Color
    let isActive: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(AppFont.body(size: 10, weight: .semibold))
                .foregroundStyle(isActive ? color : .white.opacity(0.4))
            Text("\(Int(angle))°")
                .font(AppFont.mono(size: 16))
                .foregroundStyle(isActive ? color : .white.opacity(0.4))
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(color.opacity(isActive ? 0.15 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .strokeBorder(color.opacity(isActive ? 0.4 : 0.1), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}

// MARK: - Angle String Parser
// Parses strings like "Elbow: 105° (ideal: 90-120°)" into structured data

struct ParsedAngle {
    let jointName: String      // "Elbow", "Knee", "Shoulder rotation", etc.
    let actual: Double         // 105
    let idealLow: Double       // 90
    let idealHigh: Double      // 120
    var idealMidpoint: Double { (idealLow + idealHigh) / 2 }

    /// Parse angle string from PhaseDetail.keyAngles / OverlayInstructions.anglesToHighlight
    static func parse(_ str: String) -> ParsedAngle? {
        // Pattern: "Elbow: 105° (ideal: 90-120°)" or "Arm extension: 172° (ideal: 165-180°)"
        let pattern = #"^(.+?):\s*([\d.]+)°\s*\(ideal:\s*([\d.]+)\s*-\s*([\d.]+)°?\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)),
              match.numberOfRanges >= 5 else { return nil }

        let name = String(str[Range(match.range(at: 1), in: str)!]).trimmingCharacters(in: .whitespaces)
        guard let actual = Double(str[Range(match.range(at: 2), in: str)!]),
              let low = Double(str[Range(match.range(at: 3), in: str)!]),
              let high = Double(str[Range(match.range(at: 4), in: str)!]) else { return nil }

        return ParsedAngle(jointName: name, actual: actual, idealLow: low, idealHigh: high)
    }
}

// MARK: - Angle Correction Strip (horizontal scroll of corrections)
// Used in CoachingCard to show all angle corrections for a stroke

struct AngleCorrectionStrip: View {
    let joints: [JointData]
    let angleStrings: [String]

    private let theme = DesignSystem.current

    private var parsedAngles: [ParsedAngle] {
        angleStrings.compactMap { ParsedAngle.parse($0) }
    }

    /// Filter to only show angles that are outside the ideal range
    private var outOfRangeAngles: [ParsedAngle] {
        parsedAngles.filter { parsed in
            parsed.actual < parsed.idealLow || parsed.actual > parsed.idealHigh
        }
    }

    var body: some View {
        if !outOfRangeAngles.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: 4) {
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textTertiary)
                    Text("VISUAL CORRECTION")
                        .font(AppFont.body(size: 11, weight: .bold))
                        .foregroundStyle(theme.textTertiary)
                        .tracking(0.5)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(outOfRangeAngles, id: \.jointName) { parsed in
                            AngleCorrectionView(
                                joints: joints,
                                jointName: parsed.jointName,
                                actualAngle: parsed.actual,
                                idealAngle: parsed.idealMidpoint,
                                label: parsed.jointName
                            )
                            .frame(width: 240)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleJoints: [JointData] = [
        JointData(name: "nose", x: 0.50, y: 0.88, confidence: 0.95),
        JointData(name: "left_shoulder", x: 0.41, y: 0.76, confidence: 0.95),
        JointData(name: "right_shoulder", x: 0.59, y: 0.76, confidence: 0.95),
        JointData(name: "left_elbow", x: 0.35, y: 0.63, confidence: 0.95),
        JointData(name: "right_elbow", x: 0.64, y: 0.63, confidence: 0.95),
        JointData(name: "left_wrist", x: 0.30, y: 0.55, confidence: 0.95),
        JointData(name: "right_wrist", x: 0.72, y: 0.55, confidence: 0.95),
        JointData(name: "left_hip", x: 0.43, y: 0.57, confidence: 0.95),
        JointData(name: "right_hip", x: 0.57, y: 0.57, confidence: 0.95),
        JointData(name: "left_knee", x: 0.41, y: 0.38, confidence: 0.95),
        JointData(name: "right_knee", x: 0.59, y: 0.38, confidence: 0.95),
        JointData(name: "left_ankle", x: 0.40, y: 0.20, confidence: 0.95),
        JointData(name: "right_ankle", x: 0.60, y: 0.20, confidence: 0.95),
    ]

    ZStack {
        Color.black.ignoresSafeArea()
        AngleCorrectionView(
            joints: sampleJoints,
            jointName: "elbow",
            actualAngle: 68,
            idealAngle: 90,
            label: "Elbow"
        )
        .padding()
    }
}
