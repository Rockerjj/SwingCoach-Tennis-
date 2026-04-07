import SwiftUI
import AVFoundation

// MARK: - Angle Correction View
// Shows a freeze frame from the video with a coaching tip overlay.
// No skeleton rendering -- the live video player handles that correctly.

struct AngleCorrectionView: View {
    let joints: [JointData]
    let jointName: String
    let actualAngle: Double
    let idealAngle: Double
    let label: String
    var videoURL: URL? = nil
    var timestamp: Double = 0

    @State private var frameImage: UIImage?
    let theme = DesignSystem.current

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
            if let image = frameImage {
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
        .task { await extractFrame() }
    }

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
