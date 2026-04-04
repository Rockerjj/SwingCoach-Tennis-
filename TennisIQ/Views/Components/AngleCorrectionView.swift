import SwiftUI
import AVFoundation

// MARK: - Angle Correction Animation View
// Shows the actual video frame with skeleton overlay, then morphs
// the relevant joint toward the ideal angle. Includes coach-style tips.

struct AngleCorrectionView: View {
    let joints: [JointData]
    let jointName: String
    let actualAngle: Double
    let idealAngle: Double
    let label: String
    var videoURL: URL? = nil
    var timestamp: Double = 0

    @State private var animationProgress: Double = 0
    @State private var frameImage: UIImage?
    @State private var timer: Timer?
    @State private var direction: Double = 1.0

    let theme = DesignSystem.current

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
            return ("left_shoulder", "right_shoulder", "left_hip")
        }
        return nil
    }

    private var sanitizedActual: Double { max(0, min(360, actualAngle)) }
    private var sanitizedIdeal: Double { max(0, min(360, idealAngle)) }

    private var displayAngle: Double {
        let raw = sanitizedActual + (sanitizedIdeal - sanitizedActual) * animationProgress
        return max(0, min(360, raw))
    }

    private var coachTip: String {
        let lower = jointName.lowercased()
        let diff = sanitizedIdeal - sanitizedActual

        if lower.contains("elbow") {
            return diff > 0 ? "Straighten your arm through contact" : "Keep a slight bend at contact"
        } else if lower.contains("knee") {
            return diff > 0 ? "Stay taller through your legs" : "Bend your knees more — load the legs"
        } else if lower.contains("hip") {
            return diff > 0 ? "Open your hips toward the net" : "Stay more sideways through contact"
        } else if lower.contains("arm") || lower.contains("extension") {
            return diff > 0 ? "Reach further — extend through the ball" : "Don't overextend, keep control"
        } else if lower.contains("shoulder") {
            return diff > 0 ? "Turn your shoulders perpendicular to the net" : "Don't over-rotate on the takeback"
        }
        return diff > 0 ? "Open up more through this position" : "Stay more compact here"
    }

    private var skeletonColor: Color {
        let t = animationProgress
        if t < 0.5 {
            let p = t / 0.5
            return Color(red: 0.85, green: p * 0.4, blue: 0)
        } else {
            let p = (t - 0.5) / 0.5
            return Color(red: 0.85 - p * 0.65, green: 0.4 + p * 0.25, blue: p * 0.15)
        }
    }

    private func interpolatedJoints() -> [String: CGPoint] {
        var map: [String: CGPoint] = [:]
        for j in joints {
            map[j.name] = CGPoint(x: j.x, y: j.y)
        }

        guard let chain = angleChain,
              let b = map[chain.b], let c = map[chain.c] else { return map }

        let angleDiff = sanitizedIdeal - sanitizedActual
        let rotationRadians = (angleDiff * animationProgress) * .pi / 180.0

        let dx = c.x - b.x
        let dy = c.y - b.y
        let cosR = cos(rotationRadians)
        let sinR = sin(rotationRadians)
        map[chain.c] = CGPoint(x: b.x + dx * cosR - dy * sinR, y: b.y + dx * sinR + dy * cosR)
        return map
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                // Background: real video frame or dark fallback
                if let image = frameImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 220)
                        .clipped()
                        .overlay(Color.black.opacity(0.25))
                } else {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(Color.black.opacity(0.85))
                        .frame(height: 220)
                }

                // Skeleton + angle overlay
                Canvas { context, size in
                    drawSkeletonWithAngle(context: context, size: size)
                }
                .frame(height: 220)

                // Coach tip overlay
                VStack {
                    Spacer()
                    HStack {
                        Text(coachTip)
                            .font(AppFont.body(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(skeletonColor.opacity(0.85))
                            )
                        Spacer()
                    }
                    .padding(8)
                }
                .frame(height: 220)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))

            // Label row
            HStack(spacing: Spacing.sm) {
                AngleBadge(
                    label: "Your \(coachLabel)",
                    angle: sanitizedActual,
                    color: angleSeverityColor,
                    isActive: animationProgress < 0.5
                )

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.textTertiary)

                AngleBadge(
                    label: "Ideal \(coachLabel)",
                    angle: sanitizedIdeal,
                    color: theme.success,
                    isActive: animationProgress >= 0.5
                )
            }
        }
        .task {
            await extractFrame()
            startAnimation()
        }
        .onDisappear { timer?.invalidate() }
    }

    private var coachLabel: String {
        let lower = label.lowercased()
        if lower.contains("arm") || lower.contains("extension") { return "Contact\n\(label.lowercased())" }
        return "Contact\n\(label.lowercased())"
    }

    private var angleSeverityColor: Color {
        let diff = abs(sanitizedActual - sanitizedIdeal)
        if diff < 10 { return theme.success }
        if diff < 25 { return theme.warning }
        return theme.error
    }

    // MARK: - Drawing

    private func drawSkeletonWithAngle(context: GraphicsContext, size: CGSize) {
        let jointMap = interpolatedJoints()

        func pt(_ name: String) -> CGPoint? {
            guard let n = jointMap[name] else { return nil }
            // Vision coords are in raw buffer space; for portrait video,
            // x maps to vertical and y maps to horizontal after rotation
            return CGPoint(x: n.y * size.width, y: n.x * size.height)
        }

        let defaultColor = Color.white.opacity(0.35)
        let highlightedJoints: Set<String> = {
            guard let chain = angleChain else { return [] }
            return [chain.a, chain.b, chain.c]
        }()

        for (a, b) in Self.bones {
            guard let pa = pt(a), let pb = pt(b) else { continue }
            let isHighlighted = highlightedJoints.contains(a) || highlightedJoints.contains(b)
            var path = Path()
            path.move(to: pa)
            path.addLine(to: pb)

            if isHighlighted {
                context.stroke(path, with: .color(skeletonColor.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round))
                context.stroke(path, with: .color(skeletonColor),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round))
            } else {
                context.stroke(path, with: .color(defaultColor),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }

        for (name, _) in jointMap {
            guard let p = pt(name) else { continue }
            let isHighlighted = highlightedJoints.contains(name)
            let r: CGFloat = isHighlighted ? 5 : 3
            let color = isHighlighted ? skeletonColor : defaultColor
            let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }

        if let chain = angleChain, let pivot = pt(chain.b) {
            let bubbleCenter = CGPoint(x: pivot.x + 30, y: pivot.y - 22)
            let displayStr = "\(Int(displayAngle))°"
            let bubbleRect = CGRect(x: bubbleCenter.x - 22, y: bubbleCenter.y - 13,
                                    width: 44, height: 26)
            context.fill(Path(roundedRect: bubbleRect, cornerRadius: 8),
                         with: .color(skeletonColor.opacity(0.9)))
            context.draw(
                Text(displayStr)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white),
                at: bubbleCenter
            )
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        let fps = 30.0
        let duration = 2.0
        let totalFrames = Int(fps * duration)
        let holdFrames = Int(fps * 1.2)
        var frameCount = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { _ in
            frameCount += 1
            let cycleLength = totalFrames + holdFrames
            let pos = frameCount % cycleLength

            if pos < totalFrames {
                let raw = Double(pos) / Double(totalFrames)
                let eased = raw < 0.5 ? 2 * raw * raw : -1 + (4 - 2 * raw) * raw
                animationProgress = direction > 0 ? eased : 1.0 - eased
            }

            if pos == cycleLength - 1 {
                direction *= -1
            }
        }
    }

    // MARK: - Frame Extraction

    private func extractFrame() async {
        guard let url = videoURL, timestamp > 0 else { return }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 500, height: 0)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let time = CMTime(seconds: timestamp, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            await MainActor.run { frameImage = UIImage(cgImage: cgImage) }
        } catch { }
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
                .multilineTextAlignment(.center)
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

struct ParsedAngle {
    let jointName: String
    let actual: Double
    let idealLow: Double
    let idealHigh: Double
    var idealMidpoint: Double { (idealLow + idealHigh) / 2 }

    static func parse(_ str: String) -> ParsedAngle? {
        let pattern = #"^(.+?):\s*([\d.]+)°?\s*\(ideal:\s*([\d.]+)\s*-\s*([\d.]+)°?\)"#
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

// MARK: - Angle Correction Strip

struct AngleCorrectionStrip: View {
    let joints: [JointData]
    let angleStrings: [String]
    var videoURL: URL? = nil
    var timestamp: Double = 0

    private let theme = DesignSystem.current

    private var outOfRangeAngles: [ParsedAngle] {
        angleStrings.compactMap { ParsedAngle.parse($0) }
            .filter { $0.actual < $0.idealLow || $0.actual > $0.idealHigh }
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
                                label: parsed.jointName,
                                videoURL: videoURL,
                                timestamp: timestamp
                            )
                            .frame(width: 260)
                        }
                    }
                }
            }
        }
    }
}
