import SwiftUI

struct SwingPathOverlayView: View {
    let wristPoints: [CGPoint]
    let videoNaturalSize: CGSize

    private let theme = DesignSystem.current
    private let dotSpacing: CGFloat = 8
    private let dotSize: CGFloat = 6
    private let glowRadius: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let crop = aspectFillCrop(videoSize: videoNaturalSize, viewSize: size)
                let screenPoints = wristPoints.map { toScreen($0, crop: crop) }

                guard screenPoints.count >= 2 else { return }

                let evenPoints = resamplePath(screenPoints, spacing: dotSpacing)
                let totalDots = evenPoints.count

                for (i, pt) in evenPoints.enumerated() {
                    let progress = totalDots > 1 ? Double(i) / Double(totalDots - 1) : 1.0
                    let opacity = 0.15 + 0.85 * progress
                    let radius = (dotSize * 0.4) + (dotSize * 0.6 * progress)

                    let glowRect = CGRect(
                        x: pt.x - radius - glowRadius,
                        y: pt.y - radius - glowRadius,
                        width: (radius + glowRadius) * 2,
                        height: (radius + glowRadius) * 2
                    )
                    context.fill(
                        Circle().path(in: glowRect),
                        with: .color(theme.success.opacity(opacity * 0.25))
                    )

                    let dotRect = CGRect(
                        x: pt.x - radius,
                        y: pt.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(
                        Circle().path(in: dotRect),
                        with: .color(theme.success.opacity(opacity))
                    )
                }

                if let last = evenPoints.last {
                    let headRadius = dotSize * 0.9
                    let headRect = CGRect(
                        x: last.x - headRadius,
                        y: last.y - headRadius,
                        width: headRadius * 2,
                        height: headRadius * 2
                    )
                    context.fill(Circle().path(in: headRect), with: .color(.white))

                    let outerRect = CGRect(
                        x: last.x - headRadius - 3,
                        y: last.y - headRadius - 3,
                        width: (headRadius + 3) * 2,
                        height: (headRadius + 3) * 2
                    )
                    context.stroke(
                        Circle().path(in: outerRect),
                        with: .color(theme.success),
                        lineWidth: 2
                    )
                }
            }
        }
    }

    private func resamplePath(_ points: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        var resampled: [CGPoint] = [points[0]]
        var accumulated: CGFloat = 0

        for i in 1..<points.count {
            let dx = points[i].x - points[i - 1].x
            let dy = points[i].y - points[i - 1].y
            let segmentLength = hypot(dx, dy)

            guard segmentLength > 0 else { continue }

            var remaining = segmentLength
            var fromPoint = points[i - 1]
            let dirX = dx / segmentLength
            let dirY = dy / segmentLength

            while accumulated + remaining >= spacing {
                let step = spacing - accumulated
                let newPoint = CGPoint(
                    x: fromPoint.x + dirX * step,
                    y: fromPoint.y + dirY * step
                )
                resampled.append(newPoint)
                fromPoint = newPoint
                remaining -= step
                accumulated = 0
            }
            accumulated += remaining
        }

        return resampled
    }

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

        if videoAspect < viewAspect {
            let scale = viewSize.width / videoSize.width
            return CropInfo(scale: scale, offsetX: 0, offsetY: (viewSize.height - videoSize.height * scale) / 2)
        } else {
            let scale = viewSize.height / videoSize.height
            return CropInfo(scale: scale, offsetX: (viewSize.width - videoSize.width * scale) / 2, offsetY: 0)
        }
    }

    private func toScreen(_ pt: CGPoint, crop: CropInfo) -> CGPoint {
        // Fix: X and Y were swapped. Vision uses (x=horizontal, y=vertical, bottom-origin).
        // Vision coords are in raw buffer space; for portrait video,
        // x maps to vertical and y maps to horizontal after rotation
        let videoX = pt.y * videoNaturalSize.width
        let videoY = pt.x * videoNaturalSize.height
        return CGPoint(
            x: videoX * crop.scale + crop.offsetX,
            y: videoY * crop.scale + crop.offsetY
        )
    }
}
