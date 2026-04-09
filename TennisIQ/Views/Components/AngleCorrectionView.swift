import SwiftUI
import AVFoundation

// MARK: - Angle Correction View
// Extracts a video frame, burns the skeleton overlay into the image using
// Core Graphics (same coordinate math as WireframeOverlayView), then
// displays the composite with coaching tip and angle badge.

struct AngleCorrectionView: View {
    let joints: [JointData]
    let jointName: String
    let actualAngle: Double
    let idealAngle: Double
    let label: String
    var videoURL: URL? = nil
    var timestamp: Double = 0

    @State private var compositeImage: UIImage?
    let theme = DesignSystem.current

    private var angleChain: (a: String, b: String, c: String)? {
        let side = Handedness.current == .right ? "left" : "right"
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

    private var coachTip: String {
        let lower = jointName.lowercased()
        let diff = idealAngle - actualAngle

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

    private var severityColor: Color {
        let diff = abs(idealAngle - actualAngle)
        if diff < 10 { return theme.success }
        if diff < 25 { return theme.warning }
        return theme.error
    }

    var body: some View {
        ZStack {
            if let image = compositeImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 340)
                    .overlay(Color.black.opacity(0.15))
            } else {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Color.black.opacity(0.85))
                    .frame(height: 340)
            }

            VStack {
                HStack {
                    Spacer()
                    Text("\(Int(actualAngle))°")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(severityColor.opacity(0.9)))
                }
                .padding(Spacing.sm)

                Spacer()

                HStack {
                    Text(coachTip)
                        .font(AppFont.body(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(severityColor.opacity(0.85)))
                    Spacer()
                }
                .padding(8)
            }
            .frame(height: 340)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .task { await extractFrameWithSkeleton() }
    }

    // MARK: - Frame Extraction + Skeleton Burn-in

    private func extractFrameWithSkeleton() async {
        guard let url = videoURL, timestamp > 0 else { return }
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 720, height: 0)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let time = CMTime(seconds: timestamp, preferredTimescale: 600)
        do {
            let (cgImage, _) = try await generator.image(at: time)
            let baseImage = UIImage(cgImage: cgImage)
            let composite = burnSkeletonIntoImage(baseImage)
            await MainActor.run { compositeImage = composite }
        } catch { }
    }

    private func burnSkeletonIntoImage(_ image: UIImage) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)

        let highlightedJoints: Set<String> = {
            guard let chain = angleChain else { return [] }
            return [chain.a, chain.b, chain.c]
        }()

        let bones: [(String, String)] = [
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
        ]

        let jointMap: [String: CGPoint] = {
            var map: [String: CGPoint] = [:]
            for j in joints {
                // Same mapping as WireframeOverlayView.toScreen:
                // joint.y * width for x, joint.x * height for y
                map[j.name] = CGPoint(x: j.y * size.width, y: j.x * size.height)
            }
            return map
        }()

        let skeletonColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)

        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            image.draw(in: CGRect(origin: .zero, size: size))

            // Draw only highlighted bones
            for (a, b) in bones {
                guard let pa = jointMap[a], let pb = jointMap[b] else { continue }
                let bothHighlighted = highlightedJoints.contains(a) && highlightedJoints.contains(b)
                let eitherHighlighted = highlightedJoints.contains(a) || highlightedJoints.contains(b)

                if bothHighlighted {
                    // Glow
                    cgCtx.setStrokeColor(skeletonColor.withAlphaComponent(0.4).cgColor)
                    cgCtx.setLineWidth(10)
                    cgCtx.setLineCap(.round)
                    cgCtx.move(to: pa)
                    cgCtx.addLine(to: pb)
                    cgCtx.strokePath()
                    // Core line
                    cgCtx.setStrokeColor(skeletonColor.cgColor)
                    cgCtx.setLineWidth(4)
                    cgCtx.move(to: pa)
                    cgCtx.addLine(to: pb)
                    cgCtx.strokePath()
                } else if eitherHighlighted {
                    cgCtx.setStrokeColor(skeletonColor.withAlphaComponent(0.25).cgColor)
                    cgCtx.setLineWidth(2)
                    cgCtx.setLineCap(.round)
                    cgCtx.move(to: pa)
                    cgCtx.addLine(to: pb)
                    cgCtx.strokePath()
                }
            }

            // Draw highlighted joint dots
            for (name, pt) in jointMap {
                guard highlightedJoints.contains(name) else { continue }
                let r: CGFloat = 8
                let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
                cgCtx.setFillColor(skeletonColor.cgColor)
                cgCtx.fillEllipse(in: rect)
                cgCtx.setStrokeColor(UIColor.white.cgColor)
                cgCtx.setLineWidth(2)
                cgCtx.strokeEllipse(in: rect)
            }

            // Draw angle badge near the pivot joint
            if let chain = angleChain, let pivot = jointMap[chain.b] {
                let badgeCenter = CGPoint(x: pivot.x + 40, y: pivot.y - 30)
                let text = "\(Int(actualAngle))°"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                    .foregroundColor: UIColor.white,
                ]
                let textSize = (text as NSString).size(withAttributes: attrs)
                let padding: CGFloat = 8
                let bgRect = CGRect(
                    x: badgeCenter.x - textSize.width / 2 - padding,
                    y: badgeCenter.y - textSize.height / 2 - padding / 2,
                    width: textSize.width + padding * 2,
                    height: textSize.height + padding
                )
                let path = UIBezierPath(roundedRect: bgRect, cornerRadius: 8)
                cgCtx.setFillColor(skeletonColor.withAlphaComponent(0.9).cgColor)
                cgCtx.addPath(path.cgPath)
                cgCtx.fillPath()
                (text as NSString).draw(
                    at: CGPoint(x: badgeCenter.x - textSize.width / 2, y: badgeCenter.y - textSize.height / 2),
                    withAttributes: attrs
                )
            }
        }
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
    var phaseBreakdown: PhaseBreakdown? = nil
    var poseFrames: [FramePoseData] = []

    private let theme = DesignSystem.current

    private var outOfRangeAngles: [ParsedAngle] {
        angleStrings.compactMap { ParsedAngle.parse($0) }
            .filter { $0.actual < $0.idealLow || $0.actual > $0.idealHigh }
    }

    @State private var currentPage = 0

    private func bestPhaseTimestamp(for jointName: String, index: Int = 0, total: Int = 1) -> Double {
        let lower = jointName.lowercased()
        var base: Double

        if let breakdown = phaseBreakdown {
            if lower.contains("elbow") || lower.contains("arm") || lower.contains("extension") {
                base = breakdown.contactPoint?.timestamp ?? timestamp
            } else if lower.contains("knee") {
                base = breakdown.forwardSwing?.timestamp ?? timestamp
            } else if lower.contains("hip") && !lower.contains("rotation") {
                base = breakdown.forwardSwing?.timestamp ?? timestamp
            } else if lower.contains("shoulder") && lower.contains("rotation") {
                base = breakdown.unitTurn?.timestamp ?? breakdown.backswing?.timestamp ?? timestamp
            } else {
                base = timestamp
            }
        } else if lower.contains("elbow") || lower.contains("arm") || lower.contains("extension") {
            base = timestamp
        } else if lower.contains("knee") {
            base = timestamp - 0.4
        } else if lower.contains("hip") && !lower.contains("rotation") {
            base = timestamp - 0.3
        } else if lower.contains("shoulder") && lower.contains("rotation") {
            base = timestamp - 0.6
        } else {
            base = timestamp
        }

        // Spread corrections so each slide shows a slightly different frame
        if total > 1 {
            let spread = 0.15
            let offset = (Double(index) - Double(total - 1) / 2.0) * spread
            base += offset
        }
        return max(0, base)
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
                        let phaseTime = bestPhaseTimestamp(for: parsed.jointName, index: index, total: outOfRangeAngles.count)
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
