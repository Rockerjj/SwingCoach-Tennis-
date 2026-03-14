import SwiftUI
import AVFoundation

/// Extracts a freeze frame from video at a given timestamp and overlays
/// skeleton wireframe with highlighted problem joints and angle labels.
struct PhaseFrameCaptureView: View {
    let videoURL: URL?
    let timestamp: Double
    let poseFrames: [FramePoseData]
    let keyAngles: [String]
    var height: CGFloat = 200

    @State private var frameImage: UIImage?
    @State private var pulseScale: CGFloat = 1.0

    private let theme = DesignSystem.current

    // Skeleton bones (same as WireframeOverlayView)
    private let bones: [(String, String)] = [
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
        ("right_knee", "right_ankle")
    ]

    private static let headJoints: Set<String> = [
        "nose", "left_eye", "right_eye", "left_ear", "right_ear"
    ]

    /// Find the nearest pose frame to our timestamp
    private var nearestFrame: FramePoseData? {
        guard !poseFrames.isEmpty else { return nil }
        return poseFrames.min(by: { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) })
    }

    /// Joints that should be highlighted based on keyAngles
    private var highlightedJointNames: Set<String> {
        let side = Handedness.current == .right ? "right" : "left"
        var joints = Set<String>()
        for angle in keyAngles {
            let lower = angle.lowercased()
            if lower.contains("elbow") { joints.insert("\(side)_elbow") }
            if lower.contains("shoulder") { joints.insert("\(side)_shoulder"); joints.insert("left_shoulder"); joints.insert("right_shoulder") }
            if lower.contains("wrist") { joints.insert("\(side)_wrist") }
            if lower.contains("knee") { joints.insert("\(side)_knee") }
            if lower.contains("hip") { joints.insert("\(side)_hip") }
            if lower.contains("ankle") { joints.insert("\(side)_ankle") }
            if lower.contains("spine") || lower.contains("torso") || lower.contains("rotation") {
                joints.insert("left_shoulder"); joints.insert("right_shoulder")
                joints.insert("left_hip"); joints.insert("right_hip")
            }
        }
        return joints
    }

    /// Parse angle labels for overlay display
    private var angleLabels: [(joint: String, text: String)] {
        let side = Handedness.current == .right ? "right" : "left"
        var labels: [(String, String)] = []
        for angle in keyAngles {
            let lower = angle.lowercased()
            var jointName: String?
            if lower.contains("elbow") { jointName = "\(side)_elbow" }
            else if lower.contains("shoulder") { jointName = "\(side)_shoulder" }
            else if lower.contains("wrist") { jointName = "\(side)_wrist" }
            else if lower.contains("knee") { jointName = "\(side)_knee" }
            else if lower.contains("hip") { jointName = "\(side)_hip" }
            if let name = jointName {
                labels.append((name, angle))
            }
        }
        return labels
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(theme.surfaceSecondary)

            if let image = frameImage {
                GeometryReader { geo in
                    let bodyJoints = nearestFrame?.joints.filter { !Self.headJoints.contains($0.name) } ?? []
                    let jointMap = Dictionary(uniqueKeysWithValues: bodyJoints.map { ($0.name, $0) })

                    ZStack {
                        // Video frame
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()

                        // Dark overlay for contrast
                        Color.black.opacity(0.3)

                        // Skeleton overlay
                        skeletonOverlay(joints: bodyJoints, jointMap: jointMap, size: geo.size, imageSize: CGSize(width: image.size.width, height: image.size.height))

                        // Angle labels
                        angleLabelOverlay(jointMap: jointMap, size: geo.size, imageSize: CGSize(width: image.size.width, height: image.size.height))
                    }
                }
            } else {
                VStack(spacing: Spacing.xs) {
                    ProgressView()
                        .tint(theme.accent)
                    Text("Loading frame...")
                        .font(AppFont.body(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        .task(id: timestamp) {
            frameImage = nil
            await extractFrame()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.5
            }
        }
    }

    private func skeletonOverlay(joints: [JointData], jointMap: [String: JointData], size: CGSize, imageSize: CGSize) -> some View {
        let crop = aspectFillCrop(videoSize: imageSize, viewSize: size)

        return ZStack {
            // Bones
            Canvas { context, canvasSize in
                let c = aspectFillCrop(videoSize: imageSize, viewSize: canvasSize)
                for (a, b) in bones {
                    guard let ja = jointMap[a], let jb = jointMap[b] else { continue }
                    let ptA = toScreen(ja, crop: c, videoSize: imageSize)
                    let ptB = toScreen(jb, crop: c, videoSize: imageSize)

                    let isHighlighted = highlightedJointNames.contains(a) || highlightedJointNames.contains(b)
                    let lineColor = isHighlighted ? theme.skeletonWarning : theme.trajectoryLine
                    let lineWidth: CGFloat = isHighlighted ? 4 : 2.5

                    var p = Path()
                    p.move(to: ptA)
                    p.addLine(to: ptB)
                    context.stroke(p, with: .color(lineColor.opacity(0.9)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                }
            }

            // Joint dots
            ForEach(joints, id: \.name) { j in
                let isHighlighted = highlightedJointNames.contains(j.name)
                let pos = toScreen(j, crop: crop, videoSize: imageSize)

                if isHighlighted {
                    Circle()
                        .stroke(theme.skeletonWarning, lineWidth: 2)
                        .frame(width: 18, height: 18)
                        .scaleEffect(pulseScale)
                        .opacity(Double(2.0 - pulseScale))
                        .position(pos)

                    Circle()
                        .fill(theme.skeletonWarning)
                        .frame(width: 9, height: 9)
                        .shadow(color: theme.skeletonWarning.opacity(0.5), radius: 4)
                        .position(pos)
                } else {
                    Circle()
                        .fill(theme.skeletonStroke)
                        .frame(width: 7, height: 7)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .position(pos)
                }
            }
        }
    }

    private func angleLabelOverlay(jointMap: [String: JointData], size: CGSize, imageSize: CGSize) -> some View {
        let crop = aspectFillCrop(videoSize: imageSize, viewSize: size)
        // Only show the single most critical label to avoid clutter
        let visibleLabels = Array(angleLabels.prefix(1))

        return ZStack {
            ForEach(Array(visibleLabels.enumerated()), id: \.offset) { _, label in
                if let joint = jointMap[label.joint] {
                    let pos = toScreen(joint, crop: crop, videoSize: imageSize)
                    Text(label.text)
                        .font(AppFont.mono(size: 6, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                        .position(x: pos.x + 36, y: pos.y - 18)
                }
            }
        }
    }

    private func extractFrame() async {
        guard let url = videoURL else { return }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let time = CMTime(seconds: timestamp, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            await MainActor.run {
                self.frameImage = UIImage(cgImage: cgImage)
            }
        } catch {
            // Failed to extract frame — leave as nil
        }
    }

    // MARK: - Coordinate Mapping

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
}
