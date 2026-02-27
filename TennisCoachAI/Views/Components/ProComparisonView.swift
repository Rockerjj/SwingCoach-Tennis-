import SwiftUI

struct ProComparisonView: View {
    let userJoints: [JointData]
    let proName: String
    let strokeType: StrokeType
    let alignmentScores: [AlignmentScore]
    let windowBadges: [WindowBadge]

    private let theme = DesignSystem.current
    private let proService = ProComparisonService()

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

    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack(alignment: .center) {
                HStack(spacing: 0) {
                    skeletonHalf(
                        joints: userJoints,
                        label: "You",
                        color: Color(hex: "4A90D9")
                    )
                    Rectangle()
                        .fill(theme.surfaceSecondary)
                        .frame(width: 2)
                    skeletonHalf(
                        joints: proService.getProPoseData(proName: proName, stroke: strokeType, phase: .contactPoint) ?? [],
                        label: proName,
                        color: theme.accentSecondary
                    )
                }
                .frame(height: 220)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(Color(hex: "1A2332"))
                )
                .overlay(alignment: .topTrailing) {
                    if !windowBadges.isEmpty {
                        HStack(spacing: Spacing.xxs) {
                            ForEach(windowBadges) { badge in
                                Text(badge.label)
                                    .font(AppFont.body(size: 10, weight: .semibold))
                                    .foregroundStyle(zoneColor(badge.status))
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xxs)
                                    .background(
                                        Capsule().fill(theme.surfaceElevated).opacity(0.95)
                                    )
                            }
                        }
                        .padding(Spacing.sm)
                    }
                }
            }

            VStack(spacing: Spacing.xs) {
                ForEach(alignmentScores) { score in
                    alignmentRow(score)
                }
            }
        }
    }

    private func skeletonHalf(joints: [JointData], label: String, color: Color) -> some View {
        let map = Dictionary(uniqueKeysWithValues: joints.map { ($0.name, $0) })

        return VStack(spacing: Spacing.xs) {
            Text(label)
                .font(AppFont.body(size: 12, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            Canvas { context, size in
                let w = size.width
                let h = size.height - 24
                for (a, b) in bones {
                    guard let ja = map[a], let jb = map[b] else { continue }
                    let ptA = toView(ja, width: w, height: h)
                    let ptB = toView(jb, width: w, height: h)
                    var p = Path()
                    p.move(to: ptA)
                    p.addLine(to: ptB)
                    context.stroke(
                        p,
                        with: .color(color.opacity(0.9)),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.sm)
    }

    private func toView(_ joint: JointData, width: CGFloat, height: CGFloat) -> CGPoint {
        let x = joint.x * width
        let y = (1 - joint.y) * height
        return CGPoint(x: x, y: y)
    }

    private func alignmentRow(_ score: AlignmentScore) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(score.bodyGroup)
                .font(AppFont.body(size: 13, weight: .medium))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 100, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(theme.surfaceSecondary)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(zoneColor(score.status))
                        .frame(width: geo.size.width * CGFloat(score.percentage) / 100, height: 8)
                }
            }
            .frame(height: 8)

            Text("\(score.percentage)%")
                .font(AppFont.mono(size: 12, weight: .bold))
                .foregroundStyle(zoneColor(score.status))
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func zoneColor(_ status: ZoneStatus) -> Color {
        switch status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }
}
