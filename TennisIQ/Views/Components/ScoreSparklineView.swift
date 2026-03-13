import SwiftUI

/// Mini sparkline showing session score history as a connected line with dots
struct ScoreSparklineView: View {
    let scores: [Double]
    var width: CGFloat = 160
    var height: CGFloat = 40
    private let theme = DesignSystem.current

    var body: some View {
        Canvas { context, size in
            guard scores.count >= 2 else { return }

            let minScore = (scores.min() ?? 0) - 5
            let maxScore = (scores.max() ?? 100) + 5
            let range = max(maxScore - minScore, 1)

            let stepX = size.width / CGFloat(scores.count - 1)
            let points: [CGPoint] = scores.enumerated().map { i, score in
                let x = CGFloat(i) * stepX
                let y = size.height - ((score - minScore) / range) * size.height
                return CGPoint(x: x, y: y)
            }

            // Draw line
            var linePath = Path()
            linePath.move(to: points[0])
            for i in 1..<points.count {
                linePath.addLine(to: points[i])
            }
            context.stroke(
                linePath,
                with: .color(Color(hex: "E5E7EB")),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )

            // Draw dots (all except last)
            for i in 0..<(points.count - 1) {
                let dot = Path(ellipseIn: CGRect(
                    x: points[i].x - 2.5,
                    y: points[i].y - 2.5,
                    width: 5, height: 5
                ))
                context.fill(dot, with: .color(theme.textTertiary))
            }

            // Draw last dot highlighted
            if let last = points.last {
                // Outer ring
                let outerRing = Path(ellipseIn: CGRect(
                    x: last.x - 7, y: last.y - 7,
                    width: 14, height: 14
                ))
                context.stroke(outerRing, with: .color(theme.success.opacity(0.3)), lineWidth: 1)

                // Inner dot
                let innerDot = Path(ellipseIn: CGRect(
                    x: last.x - 4, y: last.y - 4,
                    width: 8, height: 8
                ))
                context.fill(innerDot, with: .color(theme.success))
            }
        }
        .frame(width: width, height: height)
    }
}
