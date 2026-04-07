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

    private func computeAngle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        let ba = (x: a.x - b.x, y: a.y - b.y)
        let bc = (x: c.x - b.x, y: c.y - b.y)
        let dot = ba.x * bc.x + ba.y * bc.y
        let magBA = sqrt(ba.x * ba.x + ba.y * ba.y)
        let magBC = sqrt(bc.x * bc.x + bc.y * bc.y)
        guard magBA > 0, magBC > 0 else { return 0 }
        let cosAngle = max(-1, min(1, dot / (magBA * magBC)))
        return acos(cosAngle) * 180 / .pi
    }

    /// Convert all joints to screen coordinates, then rotate the highlighted
    /// chain in screen space so the animation is visible after the x/y swap.
    private func screenJoints(size: CGSize) -> [String: CGPoint] {
        let imageSize = frameImage.map { CGSize(width: $0.size.width, height: $0.size.height) }
            ?? CGSize(width: 1080, height: 1920)
        let crop = aspectFitCrop(imageSize: imageSize, viewSize: size)

        var map: [String: CGPoint] = [:]
        for j in joints {
            let raw = CGPoint(x: j.x, y: j.y)
            map[j.name] = toScreen(raw, crop: crop, imageSize: imageSize)
        }


        guard let chain = angleChain,
              let a = map[chain.a], let b = map[chain.b], let c = map[chain.c] else { return map }

        let currentAngle = computeAngle(a, b, c)
        let targetAngle = currentAngle + (sanitizedIdeal - currentAngle) * animationProgress

        // Probe to find which rotation direction increases the angle
        let probeRad = 1.0 * .pi / 180.0
        let dx = c.x - b.x
        let dy = c.y - b.y
        let probePt = CGPoint(
            x: b.x + dx * cos(probeRad) - dy * sin(probeRad),
            y: b.y + dx * sin(probeRad) + dy * cos(probeRad)
        )
        let probeAngle = computeAngle(a, b, probePt)
        let positiveRotationIncreasesAngle = probeAngle > currentAngle

        let angleDelta = targetAngle - currentAngle
        let rotationDegrees = positiveRotationIncreasesAngle ? angleDelta : -angleDelta
        let rotationRadians = rotationDegrees * .pi / 180.0
        let cosR = cos(rotationRadians)
        let sinR = sin(rotationRadians)

        // Rotate endpoint c around pivot b, and also move any joints
        // further down the chain (e.g., wrist when elbow is the pivot)
        let chainJoints = [chain.c]
        for name in chainJoints {
            guard let pt = map[name] else { continue }
            let relX = pt.x - b.x
            let relY = pt.y - b.y
            map[name] = CGPoint(
                x: b.x + relX * cosR - relY * sinR,
                y: b.y + relX * sinR + relY * cosR
            )
        }
        return map
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                // Background: real video frame or dark fallback
                if let image = frameImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 340)
                        .overlay(Color.black.opacity(0.25))
                } else {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(Color.black.opacity(0.85))
                        .frame(height: 340)
                }

                // Skeleton + angle overlay
                Canvas { context, size in
                    drawSkeletonWithAngle(context: context, size: size)
                }
                .frame(height: 340)

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
                .frame(height: 340)

            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .task {
            await extractFrame()
            startAnimation()
        }
        .onDisappear { timer?.invalidate() }
    }

    // coachLabel and angleSeverityColor removed — angle badges no longer shown

    // MARK: - Coordinate Mapping

    private struct CropInfo {
        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
    }

    private func aspectFillCrop(imageSize: CGSize, viewSize: CGSize) -> CropInfo {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CropInfo(scale: 1, offsetX: 0, offsetY: 0)
        }
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat

        if imageAspect < viewAspect {
            scale = viewSize.width / imageSize.width
            offsetX = 0
            offsetY = (viewSize.height - imageSize.height * scale) / 2.0
        } else {
            scale = viewSize.height / imageSize.height
            offsetX = (viewSize.width - imageSize.width * scale) / 2.0
            offsetY = 0
        }
        return CropInfo(scale: scale, offsetX: offsetX, offsetY: offsetY)
    }

    private func aspectFitCrop(imageSize: CGSize, viewSize: CGSize) -> CropInfo {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CropInfo(scale: 1, offsetX: 0, offsetY: 0)
        }
        let scaleW = viewSize.width / imageSize.width
        let scaleH = viewSize.height / imageSize.height
        let scale = min(scaleW, scaleH)
        let offsetX = (viewSize.width - imageSize.width * scale) / 2.0
        let offsetY = (viewSize.height - imageSize.height * scale) / 2.0
        return CropInfo(scale: scale, offsetX: offsetX, offsetY: offsetY)
    }

    private func toScreen(_ n: CGPoint, crop: CropInfo, imageSize: CGSize) -> CGPoint {
        // Vision coords are in raw buffer space with bottom-left origin.
        // For portrait video, x/y are swapped after 90-degree rotation,
        // and the vertical axis is inverted (Vision y-up vs UIKit y-down).
        let videoX = (1.0 - n.y) * imageSize.width
        let videoY = n.x * imageSize.height
        return CGPoint(
            x: videoX * crop.scale + crop.offsetX,
            y: videoY * crop.scale + crop.offsetY
        )
    }

    // MARK: - Drawing

    private func drawSkeletonWithAngle(context: GraphicsContext, size: CGSize) {
        let jointMap = screenJoints(size: size)

        let highlightedJoints: Set<String> = {
            guard let chain = angleChain else { return [] }
            return [chain.a, chain.b, chain.c]
        }()

        // Only draw bones where BOTH endpoints are in the highlighted chain
        for (a, b) in Self.bones {
            guard let pa = jointMap[a], let pb = jointMap[b] else { continue }
            guard highlightedJoints.contains(a) && highlightedJoints.contains(b) else { continue }
            var path = Path()
            path.move(to: pa)
            path.addLine(to: pb)
            context.stroke(path, with: .color(skeletonColor.opacity(0.4)),
                style: StrokeStyle(lineWidth: 8, lineCap: .round))
            context.stroke(path, with: .color(skeletonColor),
                style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }

        // Only draw dots for highlighted joints
        for (name, pt) in jointMap {
            guard highlightedJoints.contains(name) else { continue }
            let r: CGFloat = 5
            let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect), with: .color(skeletonColor))
        }

        if let chain = angleChain, let pivot = jointMap[chain.b] {
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
        let animDuration = 2.0
        let holdDuration = 1.5
        let animFrames = Int(fps * animDuration)
        let holdFrames = Int(fps * holdDuration)
        let halfCycle = animFrames + holdFrames   // animate + hold
        let fullCycle = halfCycle * 2             // forward + back
        var frameCount = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { _ in
            frameCount += 1
            let pos = frameCount % fullCycle

            if pos < animFrames {
                // Animate forward: actual -> ideal
                let raw = Double(pos) / Double(animFrames)
                let eased = raw < 0.5 ? 2 * raw * raw : -1 + (4 - 2 * raw) * raw
                animationProgress = eased
            } else if pos < halfCycle {
                // Hold at ideal
                animationProgress = 1.0
            } else if pos < halfCycle + animFrames {
                // Animate back: ideal -> actual
                let raw = Double(pos - halfCycle) / Double(animFrames)
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

// AngleBadge removed — replaced by coach tip capsule overlay

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
    var phaseBreakdown: PhaseBreakdown? = nil
    var poseFrames: [FramePoseData] = []

    private let theme = DesignSystem.current

    private var outOfRangeAngles: [ParsedAngle] {
        angleStrings.compactMap { ParsedAngle.parse($0) }
            .filter { $0.actual < $0.idealLow || $0.actual > $0.idealHigh }
    }

    @State private var currentPage = 0

    private func bestPhaseTimestamp(for jointName: String) -> Double {
        let lower = jointName.lowercased()

        // Use real phase breakdown timestamps when available
        if let breakdown = phaseBreakdown {
            if lower.contains("elbow") || lower.contains("arm") || lower.contains("extension") {
                return breakdown.contactPoint?.timestamp ?? timestamp
            } else if lower.contains("knee") {
                return breakdown.forwardSwing?.timestamp ?? timestamp
            } else if lower.contains("hip") && !lower.contains("rotation") {
                return breakdown.forwardSwing?.timestamp ?? timestamp
            } else if lower.contains("shoulder") && lower.contains("rotation") {
                return breakdown.unitTurn?.timestamp ?? breakdown.backswing?.timestamp ?? timestamp
            }
            return timestamp
        }

        // Fallback: estimate phase offsets from the stroke contact timestamp
        if lower.contains("elbow") || lower.contains("arm") || lower.contains("extension") {
            return timestamp
        } else if lower.contains("knee") {
            return timestamp - 0.4
        } else if lower.contains("hip") && !lower.contains("rotation") {
            return timestamp - 0.3
        } else if lower.contains("shoulder") && lower.contains("rotation") {
            return timestamp - 0.6
        }
        return timestamp
    }

    private func nearestJoints(for phaseTimestamp: Double) -> [JointData] {
        guard !poseFrames.isEmpty else { return joints }
        if let nearest = poseFrames.min(by: { abs($0.timestamp - phaseTimestamp) < abs($1.timestamp - phaseTimestamp) }),
           !nearest.joints.isEmpty {
            return nearest.joints
        }
        return joints
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

                    Spacer()

                    if outOfRangeAngles.count > 1 {
                        Text("\(currentPage + 1)/\(outOfRangeAngles.count)")
                            .font(AppFont.mono(size: 11))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                TabView(selection: $currentPage) {
                    ForEach(Array(outOfRangeAngles.enumerated()), id: \.element.jointName) { index, parsed in
                        let phaseTime = bestPhaseTimestamp(for: parsed.jointName)
                        let phaseJoints = nearestJoints(for: phaseTime)
                        AngleCorrectionView(
                            joints: phaseJoints,
                            jointName: parsed.jointName,
                            actualAngle: parsed.actual,
                            idealAngle: parsed.idealMidpoint,
                            label: parsed.jointName,
                            videoURL: videoURL,
                            timestamp: phaseTime
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: outOfRangeAngles.count > 1 ? .automatic : .never))
                .frame(height: 360)

            }
        }
    }
}
