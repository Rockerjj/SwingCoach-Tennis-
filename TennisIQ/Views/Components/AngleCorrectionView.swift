import SwiftUI
import AVFoundation

// MARK: - Angle Correction Animation View
// Shows the actual video frame with skeleton overlay, then morphs
// the relevant joint toward the ideal angle. The skeleton visibly moves
// from the player's actual position to the ideal coaching position.

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

        if lower.contains("elbow") || lower.contains("arm") || lower.contains("extension") {
            return diff > 0 ? "Straighten your arm through contact" : "Keep a slight bend at contact"
        } else if lower.contains("knee") {
            return diff > 0 ? "Stay taller through your legs" : "Bend your knees more — load the legs"
        } else if lower.contains("hip") {
            return diff > 0 ? "Open your hips toward the net" : "Stay more sideways through contact"
        } else if lower.contains("shoulder") {
            return diff > 0 ? "Turn your shoulders more" : "Don't over-rotate on the takeback"
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

    // MARK: - Screen-Space Interpolation
    // Instead of rotating in Vision's raw coordinate space (which gets flipped
    // by the portrait x/y swap), we:
    // 1. Convert all joints to screen coordinates first
    // 2. Compute the actual angle in screen space
    // 3. Rotate the distal joint (c) around the pivot (b) in screen space
    // 4. Draw directly — no coordinate transform confusion

    private func screenJoints(size: CGSize) -> [String: CGPoint] {
        var map: [String: CGPoint] = [:]
        for j in joints {
            // Vision portrait mapping: x→vertical, y→horizontal
            map[j.name] = CGPoint(x: j.y * size.width, y: j.x * size.height)
        }
        return map
    }

    private func computeScreenAngle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        let ba = CGPoint(x: a.x - b.x, y: a.y - b.y)
        let bc = CGPoint(x: c.x - b.x, y: c.y - b.y)
        let dot = ba.x * bc.x + ba.y * bc.y
        let magBA = sqrt(ba.x * ba.x + ba.y * ba.y)
        let magBC = sqrt(bc.x * bc.x + bc.y * bc.y)
        guard magBA > 0, magBC > 0 else { return 0 }
        let cosAngle = max(-1, min(1, dot / (magBA * magBC)))
        return acos(cosAngle) * 180 / .pi
    }

    private func interpolatedScreenJoints(size: CGSize) -> [String: CGPoint] {
        var map = screenJoints(size: size)

        guard let chain = angleChain,
              let a = map[chain.a], let b = map[chain.b], let c = map[chain.c]
        else { return map }

        let currentAngle = computeScreenAngle(a, b, c)
        guard currentAngle > 0 else { return map }

        // How much we need the angle to change
        let targetAngle = currentAngle + (sanitizedIdeal - currentAngle) * animationProgress
        let angleDelta = targetAngle - currentAngle

        // Determine rotation direction: probe +1° in screen space
        let dx = c.x - b.x
        let dy = c.y - b.y
        let probeRad = 1.0 * .pi / 180.0
        let probeC = CGPoint(
            x: b.x + dx * cos(probeRad) - dy * sin(probeRad),
            y: b.y + dx * sin(probeRad) + dy * cos(probeRad)
        )
        let probeAngle = computeScreenAngle(a, b, probeC)
        let posRotIncreases = probeAngle > currentAngle

        let rotDeg = posRotIncreases ? angleDelta : -angleDelta
        let rotRad = rotDeg * .pi / 180.0

        let cosR = cos(rotRad)
        let sinR = sin(rotRad)

        // Move joint C (the distal joint)
        let newC = CGPoint(
            x: b.x + dx * cosR - dy * sinR,
            y: b.y + dx * sinR + dy * cosR
        )
        map[chain.c] = newC

        // For arm chains (shoulder-elbow-wrist), also propagate:
        // If chain is shoulder-elbow-wrist, we rotated the wrist around the elbow.
        // But if chain is shoulder-elbow-wrist and we want to straighten the ARM,
        // we should check if there are downstream joints to also move.
        // For elbow angle: a=shoulder, b=elbow, c=wrist — wrist moves. Good.
        // For arm extension: same chain. Good.

        return map
    }

    var body: some View {
        ZStack {
            // Background: real video frame or dark fallback
            if let image = frameImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 240)
                    .clipped()
                    .overlay(Color.black.opacity(0.25))
            } else {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Color.black.opacity(0.85))
                    .frame(height: 240)
            }

            // Skeleton + angle overlay
            Canvas { context, size in
                drawSkeleton(context: context, size: size)
            }
            .frame(height: 240)

            // Coach tip overlay at bottom
            VStack {
                Spacer()
                HStack {
                    Text(coachTip)
                        .font(AppFont.body(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(skeletonColor.opacity(0.9))
                        )
                    Spacer()
                }
                .padding(10)
            }
            .frame(height: 240)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .task {
            await extractFrame()
            startAnimation()
        }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Drawing

    private func drawSkeleton(context: GraphicsContext, size: CGSize) {
        let jointMap = interpolatedScreenJoints(size: size)

        let defaultColor = Color.white.opacity(0.35)
        let highlightedJoints: Set<String> = {
            guard let chain = angleChain else { return [] }
            return [chain.a, chain.b, chain.c]
        }()

        // Draw bones
        for (a, b) in Self.bones {
            guard let pa = jointMap[a], let pb = jointMap[b] else { continue }
            let isHighlighted = highlightedJoints.contains(a) || highlightedJoints.contains(b)
            var path = Path()
            path.move(to: pa)
            path.addLine(to: pb)

            if isHighlighted {
                // Glow + solid line for highlighted bones
                context.stroke(path, with: .color(skeletonColor.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round))
                context.stroke(path, with: .color(skeletonColor),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round))
            } else {
                context.stroke(path, with: .color(defaultColor),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }

        // Draw joint dots
        for (name, pt) in jointMap {
            let isHighlighted = highlightedJoints.contains(name)
            let r: CGFloat = isHighlighted ? 6 : 3
            let color = isHighlighted ? skeletonColor : defaultColor
            let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color))
        }

        // Angle bubble at the pivot joint
        if let chain = angleChain, let pivot = jointMap[chain.b] {
            let bubbleCenter = CGPoint(x: pivot.x + 35, y: pivot.y - 25)
            let displayStr = "\(Int(displayAngle))°"
            let bubbleRect = CGRect(x: bubbleCenter.x - 24, y: bubbleCenter.y - 14,
                                    width: 48, height: 28)
            context.fill(Path(roundedRect: bubbleRect, cornerRadius: 8),
                         with: .color(skeletonColor.opacity(0.9)))
            context.draw(
                Text(displayStr)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white),
                at: bubbleCenter
            )
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        let fps = 30.0
        let forwardDuration = 2.0
        let holdDuration = 1.5
        let totalForwardFrames = Int(fps * forwardDuration)
        let holdFrames = Int(fps * holdDuration)
        let cycleLength = totalForwardFrames + holdFrames + totalForwardFrames + holdFrames
        var frameCount = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { _ in
            frameCount += 1
            let pos = frameCount % cycleLength

            if pos < totalForwardFrames {
                // Animate forward: actual → ideal
                let raw = Double(pos) / Double(totalForwardFrames)
                let eased = raw < 0.5 ? 2 * raw * raw : -1 + (4 - 2 * raw) * raw
                animationProgress = eased
            } else if pos < totalForwardFrames + holdFrames {
                // Hold at ideal
                animationProgress = 1.0
            } else if pos < totalForwardFrames + holdFrames + totalForwardFrames {
                // Animate back: ideal → actual
                let backPos = pos - totalForwardFrames - holdFrames
                let raw = Double(backPos) / Double(totalForwardFrames)
                let eased = raw < 0.5 ? 2 * raw * raw : -1 + (4 - 2 * raw) * raw
                animationProgress = 1.0 - eased
            } else {
                // Hold at actual
                animationProgress = 0.0
            }
        }
    }

    // MARK: - Frame Extraction

    private func extractFrame() async {
        guard let url = videoURL, timestamp > 0 else { return }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 0)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let time = CMTime(seconds: timestamp, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            await MainActor.run { frameImage = UIImage(cgImage: cgImage) }
        } catch { }
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

// MARK: - Angle Correction Strip (Full-Width Swipeable Pages)

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

    @State private var currentPage = 0

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

                    Spacer()

                    if outOfRangeAngles.count > 1 {
                        Text("\(currentPage + 1)/\(outOfRangeAngles.count)")
                            .font(AppFont.mono(size: 11))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                // Full-width, swipeable pages
                TabView(selection: $currentPage) {
                    ForEach(Array(outOfRangeAngles.enumerated()), id: \.element.jointName) { index, parsed in
                        AngleCorrectionView(
                            joints: joints,
                            jointName: parsed.jointName,
                            actualAngle: parsed.actual,
                            idealAngle: parsed.idealMidpoint,
                            label: parsed.jointName,
                            videoURL: videoURL,
                            timestamp: timestamp
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: outOfRangeAngles.count > 1 ? .automatic : .never))
                .frame(height: 260)
            }
        }
    }
}
