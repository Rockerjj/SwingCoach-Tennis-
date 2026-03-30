import SwiftUI
import AVFoundation

struct SkeletonCorrectionView: View {
    let videoURL: URL?
    let userJoints: [JointData]
    let phaseTimestamp: Double
    let keyAngles: [String]
    let phase: SwingPhase

    @State private var frameImage: UIImage?
    @State private var lerpFactor: Double = 0
    @State private var timer: Timer?
    @State private var isPaused = false
    @State private var animationDirection: Double = 1.0

    private let theme = DesignSystem.current
    private let parsedAngles: [ParsedAngle]
    private let correctedJoints: [JointData]

    init(videoURL: URL?, userJoints: [JointData], phaseTimestamp: Double, keyAngles: [String], phase: SwingPhase) {
        self.videoURL = videoURL
        self.userJoints = userJoints
        self.phaseTimestamp = phaseTimestamp
        self.keyAngles = keyAngles
        self.phase = phase

        let parsed = AngleParser.parseAll(keyAngles)
        self.parsedAngles = parsed

        var corrections: [String: Double] = [:]
        for angle in parsed where !angle.isInRange {
            corrections[angle.name + "_angle"] = angle.idealMidpoint
        }
        self.correctedJoints = JointCorrector.computeCorrectedJoints(
            userJoints: userJoints,
            corrections: corrections
        )
    }

    private var interpolatedJoints: [JointData] {
        JointCorrector.interpolateJoints(from: userJoints, to: correctedJoints, factor: lerpFactor)
    }

    private var skeletonColor: Color {
        let c = JointCorrector.correctionColor(factor: lerpFactor)
        return Color(red: c.r, green: c.g, blue: c.b)
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            headerRow

            ZStack {
                frameBackground
                skeletonCanvas
                angleLabelsOverlay
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))

            playbackControls
        }
        .padding(Spacing.md)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .task {
            await extractFrame()
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Image(systemName: "figure.tennis")
                .foregroundStyle(skeletonColor)
            Text("Form Correction — \(phase.displayName)")
                .font(AppFont.body(size: 14, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text(lerpFactor < 0.5 ? "Your form" : "Corrected")
                .font(AppFont.body(size: 12, weight: .medium))
                .foregroundStyle(skeletonColor)
                .animation(.easeInOut(duration: 0.3), value: lerpFactor < 0.5)
        }
    }

    // MARK: - Video Frame Background

    private var frameBackground: some View {
        Group {
            if let image = frameImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(Color.black.opacity(0.3))
            } else {
                theme.background
            }
        }
    }

    // MARK: - Skeleton Canvas

    private var skeletonCanvas: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let imageSize = frameImage.map {
                    CGSize(width: $0.size.width, height: $0.size.height)
                } ?? CGSize(width: 1080, height: 1920)

                let joints = interpolatedJoints
                let jointMap = Dictionary(uniqueKeysWithValues: joints.map { ($0.name, $0) })
                let crop = aspectFillCrop(videoSize: imageSize, viewSize: size)
                let color = skeletonColor

                // Draw bones
                for (a, b) in SkeletonTopology.bones {
                    guard let ja = jointMap[a], let jb = jointMap[b],
                          ja.confidence > 0.2, jb.confidence > 0.2 else { continue }
                    let pa = toScreen(ja, crop: crop, videoSize: imageSize)
                    let pb = toScreen(jb, crop: crop, videoSize: imageSize)

                    var path = Path()
                    path.move(to: pa)
                    path.addLine(to: pb)

                    context.stroke(path,
                        with: .color(color.opacity(0.4)),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    context.stroke(path,
                        with: .color(color),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }

                // Draw joint dots
                for joint in joints where joint.confidence > 0.2 {
                    let pos = toScreen(joint, crop: crop, videoSize: imageSize)
                    let r: CGFloat = joint.name == "nose" ? 6 : 5
                    let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)),
                                 with: .color(color.opacity(0.3)))
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }

    // MARK: - Angle Labels

    private var angleLabelsOverlay: some View {
        GeometryReader { geo in
            let imageSize = frameImage.map {
                CGSize(width: $0.size.width, height: $0.size.height)
            } ?? CGSize(width: 1080, height: 1920)
            let crop = aspectFillCrop(videoSize: imageSize, viewSize: geo.size)
            let jointMap = Dictionary(uniqueKeysWithValues: interpolatedJoints.map { ($0.name, $0) })

            ForEach(parsedAngles.filter { !$0.isInRange }, id: \.name) { angle in
                let jointName = angleLabelJoint(for: angle.name)
                if let joint = jointMap[jointName], joint.confidence > 0.2 {
                    let pos = toScreen(joint, crop: crop, videoSize: imageSize)
                    let currentValue = angle.measured + (angle.idealMidpoint - angle.measured) * lerpFactor

                    Text("\(Int(currentValue))°")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(skeletonColor.opacity(0.85))
                        )
                        .position(x: pos.x + 30, y: pos.y - 16)
                }
            }
        }
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: Spacing.lg) {
            Button {
                lerpFactor = 0
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }

            Button {
                isPaused.toggle()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(theme.accent)
            }

            HStack(spacing: 4) {
                Circle().fill(Color.red).frame(width: 8, height: 8)
                Text("Your form")
                    .font(AppFont.body(size: 11))
                    .foregroundStyle(theme.textTertiary)

                Circle().fill(Color.green).frame(width: 8, height: 8)
                    .padding(.leading, 8)
                Text("Corrected")
                    .font(AppFont.body(size: 11))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        let fps = 30.0
        let duration = 2.0
        let totalFrames = Int(fps * duration)
        var frameCount = 0
        let holdFrames = Int(fps * 1.0)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / fps, repeats: true) { _ in
            guard !isPaused else { return }

            frameCount += 1
            let cycleLength = totalFrames + holdFrames
            let pos = frameCount % cycleLength

            if pos < totalFrames {
                let raw = Double(pos) / Double(totalFrames)
                if animationDirection > 0 {
                    lerpFactor = easeInOut(raw)
                } else {
                    lerpFactor = easeInOut(1.0 - raw)
                }
            }
            // Hold at end for 1 second, then reverse
            if pos == cycleLength - 1 {
                animationDirection *= -1
            }
        }
    }

    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    }

    // MARK: - Frame Extraction

    private func extractFrame() async {
        guard let url = videoURL else { return }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 0)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let time = CMTime(seconds: phaseTimestamp, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            await MainActor.run {
                self.frameImage = UIImage(cgImage: cgImage)
            }
        } catch {
            // Frame extraction failed — skeleton still renders on dark background
        }
    }

    // MARK: - Coordinate Mapping (matches PhaseFrameCaptureView)

    private struct CropInfo {
        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
    }

    private func aspectFillCrop(videoSize: CGSize, viewSize: CGSize) -> CropInfo {
        guard videoSize.width > 0, videoSize.height > 0 else {
            return CropInfo(scale: 1, offsetX: 0, offsetY: 0)
        }
        let videoAspect = videoSize.width / videoSize.height
        let viewAspect = viewSize.width / viewSize.height

        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat

        if videoAspect < viewAspect {
            scale = viewSize.width / videoSize.width
            offsetX = 0
            offsetY = (viewSize.height - videoSize.height * scale) / 2.0
        } else {
            scale = viewSize.height / videoSize.height
            offsetX = (viewSize.width - videoSize.width * scale) / 2.0
            offsetY = 0
        }
        return CropInfo(scale: scale, offsetX: offsetX, offsetY: offsetY)
    }

    private func toScreen(_ joint: JointData, crop: CropInfo, videoSize: CGSize) -> CGPoint {
        let videoX = joint.y * videoSize.width
        let videoY = joint.x * videoSize.height
        return CGPoint(
            x: videoX * crop.scale + crop.offsetX,
            y: videoY * crop.scale + crop.offsetY
        )
    }

    /// Map angle name to the joint where the label should appear
    private func angleLabelJoint(for angleName: String) -> String {
        switch angleName {
        case "elbow": return Handedness.current == .right ? "right_elbow" : "left_elbow"
        case "knee": return Handedness.current == .right ? "right_knee" : "left_knee"
        case "hip": return Handedness.current == .right ? "right_hip" : "left_hip"
        case "shoulder rotation": return "right_shoulder"
        case "arm extension": return Handedness.current == .right ? "right_wrist" : "left_wrist"
        default: return "nose"
        }
    }
}
