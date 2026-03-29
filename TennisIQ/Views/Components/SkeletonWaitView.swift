import SwiftUI

// MARK: - Skeleton Wait View
// Animated stick-figure skeleton shown during AI analysis (30-60 second wait).
// Loops through 3 tennis pose keyframes to keep users engaged.

struct SkeletonWaitView: View {
    let phase: String     // e.g. "Extracting poses..." or "Analyzing with AI..."
    let progress: Double  // 0.0 to 1.0

    // MARK: - Animation State
    @State private var currentKeyframe = 0
    @State private var lerpFactor: Double = 0
    @State private var timer: Timer?

    let theme = DesignSystem.current

    // Canonical bone connections (mirrors OverlayRenderer)
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

    // MARK: - Keyframe Poses (normalized 0–1 coords, Y=0 bottom, Y=1 top)
    // Three tennis poses: ready, backswing, follow-through
    private static let keyframes: [[String: CGPoint]] = [
        // 0: Ready position
        [
            "nose":            CGPoint(x: 0.50, y: 0.88),
            "left_shoulder":   CGPoint(x: 0.41, y: 0.76),
            "right_shoulder":  CGPoint(x: 0.59, y: 0.76),
            "left_elbow":      CGPoint(x: 0.35, y: 0.63),
            "right_elbow":     CGPoint(x: 0.64, y: 0.63),
            "left_wrist":      CGPoint(x: 0.42, y: 0.55),
            "right_wrist":     CGPoint(x: 0.57, y: 0.55),
            "left_hip":        CGPoint(x: 0.43, y: 0.57),
            "right_hip":       CGPoint(x: 0.57, y: 0.57),
            "left_knee":       CGPoint(x: 0.41, y: 0.38),
            "right_knee":      CGPoint(x: 0.59, y: 0.38),
            "left_ankle":      CGPoint(x: 0.40, y: 0.20),
            "right_ankle":     CGPoint(x: 0.60, y: 0.20),
        ],
        // 1: Backswing (right-handed forehand)
        [
            "nose":            CGPoint(x: 0.45, y: 0.88),
            "left_shoulder":   CGPoint(x: 0.36, y: 0.76),
            "right_shoulder":  CGPoint(x: 0.56, y: 0.77),
            "left_elbow":      CGPoint(x: 0.30, y: 0.65),
            "right_elbow":     CGPoint(x: 0.72, y: 0.68),
            "left_wrist":      CGPoint(x: 0.38, y: 0.58),
            "right_wrist":     CGPoint(x: 0.80, y: 0.72),
            "left_hip":        CGPoint(x: 0.40, y: 0.57),
            "right_hip":       CGPoint(x: 0.54, y: 0.57),
            "left_knee":       CGPoint(x: 0.39, y: 0.37),
            "right_knee":      CGPoint(x: 0.56, y: 0.36),
            "left_ankle":      CGPoint(x: 0.37, y: 0.19),
            "right_ankle":     CGPoint(x: 0.58, y: 0.18),
        ],
        // 2: Follow-through (arm high, rotated)
        [
            "nose":            CGPoint(x: 0.52, y: 0.89),
            "left_shoulder":   CGPoint(x: 0.42, y: 0.77),
            "right_shoulder":  CGPoint(x: 0.62, y: 0.75),
            "left_elbow":      CGPoint(x: 0.36, y: 0.64),
            "right_elbow":     CGPoint(x: 0.68, y: 0.80),
            "left_wrist":      CGPoint(x: 0.44, y: 0.58),
            "right_wrist":     CGPoint(x: 0.60, y: 0.92),
            "left_hip":        CGPoint(x: 0.44, y: 0.57),
            "right_hip":       CGPoint(x: 0.58, y: 0.57),
            "left_knee":       CGPoint(x: 0.43, y: 0.38),
            "right_knee":      CGPoint(x: 0.60, y: 0.37),
            "left_ankle":      CGPoint(x: 0.41, y: 0.20),
            "right_ankle":     CGPoint(x: 0.62, y: 0.19),
        ],
    ]

    private static let phaseLabels = ["Ready Position", "Backswing", "Follow Through"]

    // MARK: - Interpolation
    private var interpolatedJoints: [String: CGPoint] {
        let from = Self.keyframes[currentKeyframe]
        let to = Self.keyframes[(currentKeyframe + 1) % Self.keyframes.count]
        var result: [String: CGPoint] = [:]
        let t = lerpFactor
        for key in from.keys {
            guard let a = from[key], let b = to[key] else { continue }
            result[key] = CGPoint(
                x: a.x + (b.x - a.x) * t,
                y: a.y + (b.y - a.y) * t
            )
        }
        return result
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Skeleton canvas
            Canvas { context, size in
                drawSkeleton(context: context, size: size)
            }
            .frame(width: 280, height: 380)
            .background(theme.background.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Phase label
            Text(Self.phaseLabels[currentKeyframe])
                .font(AppFont.body(size: 13, weight: .semibold))
                .foregroundStyle(theme.accent)
                .animation(.easeInOut(duration: 0.4), value: currentKeyframe)

            // Progress indicator
            VStack(spacing: Spacing.xs) {
                Text(phase)
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)

                if progress > 0 && progress < 1 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.surfacePrimary)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.accent)
                                .frame(width: geo.size.width * progress, height: 4)
                                .animation(.linear(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 4)
                    .frame(maxWidth: 220)
                } else {
                    // Indeterminate shimmer dots
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            ShimmerDot(delay: Double(i) * 0.2)
                        }
                    }
                }
            }
        }
        .onAppear { startAnimation() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Canvas Drawing
    private func drawSkeleton(context: GraphicsContext, size: CGSize) {
        let joints = interpolatedJoints
        func pt(_ name: String) -> CGPoint? {
            guard let n = joints[name] else { return nil }
            // Y is flipped: canvas Y=0 is top, our coords Y=1 is top
            return CGPoint(x: n.x * size.width, y: (1.0 - n.y) * size.height)
        }

        let strokeColor = Color(red: 0.83, green: 0.58, blue: 0.16) // clay/gold accent

        // Draw bones
        for (a, b) in Self.bones {
            guard let pa = pt(a), let pb = pt(b) else { continue }
            var path = Path()
            path.move(to: pa)
            path.addLine(to: pb)
            // Glow layer
            context.stroke(path,
                with: .color(strokeColor.opacity(0.3)),
                style: StrokeStyle(lineWidth: 10, lineCap: .round))
            // Core line
            context.stroke(path,
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        // Draw joint dots
        for jointName in joints.keys {
            guard let p = pt(jointName) else { continue }
            let radius: CGFloat = jointName == "nose" ? 5 : 4
            let dotRect = CGRect(x: p.x - radius, y: p.y - radius,
                                 width: radius * 2, height: radius * 2)
            // Glow
            context.fill(Path(ellipseIn: dotRect.insetBy(dx: -3, dy: -3)),
                         with: .color(strokeColor.opacity(0.25)))
            // Dot
            context.fill(Path(ellipseIn: dotRect), with: .color(strokeColor))
        }
    }

    // MARK: - Animation Timer
    private func startAnimation() {
        let fps = 30.0
        let frameDuration = 1.0 / fps
        let framesPerKeyframe = Int(fps * 0.9) // ~0.9s per pose

        var frameCount = 0
        timer = Timer.scheduledTimer(withTimeInterval: frameDuration, repeats: true) { _ in
            frameCount += 1
            let localFrame = frameCount % framesPerKeyframe
            let newLerp = Double(localFrame) / Double(framesPerKeyframe)

            if localFrame == 0 {
                // Advance to next keyframe
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentKeyframe = (currentKeyframe + 1) % Self.keyframes.count
                }
            }
            lerpFactor = easeInOut(newLerp)
        }
    }

    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    }
}

// MARK: - Shimmer Dot (indeterminate indicator)
private struct ShimmerDot: View {
    let delay: Double
    @State private var opacity: Double = 0.3

    var body: some View {
        Circle()
            .fill(Color(red: 0.83, green: 0.58, blue: 0.16))
            .frame(width: 7, height: 7)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    opacity = 1.0
                }
            }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SkeletonWaitView(phase: "Analyzing with AI...", progress: 0.0)
    }
}
