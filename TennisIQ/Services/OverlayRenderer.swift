import Foundation
import SwiftUI
import UIKit
import CoreGraphics
import AVFoundation

/// Renders pose skeleton overlays and coaching annotations on video frames
final class OverlayRenderer {
    let theme: AppTheme

    init(theme: AppTheme = DesignSystem.current) {
        self.theme = theme
    }

    // MARK: - Skeleton Connections

    private static let boneConnections: [(String, String)] = [
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

    // MARK: - Draw Skeleton on Frame

    func drawSkeleton(
        on image: UIImage,
        poseData: FramePoseData,
        highlightJoints: Set<String> = [],
        strokeResult: StrokeResult? = nil
    ) -> UIImage {
        let size = image.size

        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return image }

        image.draw(at: .zero)

        let jointMap = Dictionary(uniqueKeysWithValues: poseData.joints.map { ($0.name, $0) })

        // Draw bone connections
        for (startName, endName) in Self.boneConnections {
            guard let start = jointMap[startName], let end = jointMap[endName] else { continue }

            let startPoint = denormalize(x: start.x, y: start.y, in: size)
            let endPoint = denormalize(x: end.x, y: end.y, in: size)

            let isHighlighted = highlightJoints.contains(startName) || highlightJoints.contains(endName)
            let lineColor = isHighlighted ? uiColor(theme.skeletonWarning) : uiColor(theme.skeletonStroke)

            context.setStrokeColor(lineColor.cgColor)
            context.setLineWidth(isHighlighted ? 4.0 : 2.5)
            context.setLineCap(.round)

            // Glow effect
            context.setShadow(offset: .zero, blur: 8, color: lineColor.withAlphaComponent(0.6).cgColor)

            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }

        context.setShadow(offset: .zero, blur: 0)

        // Draw joint dots
        for joint in poseData.joints {
            let point = denormalize(x: joint.x, y: joint.y, in: size)
            let isHighlighted = highlightJoints.contains(joint.name)
            let dotRadius: CGFloat = isHighlighted ? 6 : 4
            // in-zone highlighted joints → skeletonCorrect (green); warning/flagged → skeletonWarning (clay); default → skeletonStroke (white)
            let dotColor = isHighlighted ? uiColor(theme.skeletonWarning) : uiColor(theme.skeletonStroke)

            context.setFillColor(dotColor.cgColor)
            context.fillEllipse(in: CGRect(
                x: point.x - dotRadius,
                y: point.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            ))
        }

        // Angle info is shown in coaching cards below the video, not as floating overlays

        let resultImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resultImage
    }

    // MARK: - Angle Annotations

    private func drawAngleAnnotations(
        context: CGContext,
        jointMap: [String: JointData],
        result: StrokeResult,
        size: CGSize
    ) {
        for angleStr in result.overlayInstructions.anglesToHighlight {
            // Parse "right_elbow: 142° (ideal: 155-170°)"
            let parts = angleStr.split(separator: ":")
            guard parts.count >= 2 else { continue }

            let jointName = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let label = String(parts[1]).trimmingCharacters(in: .whitespaces)

            guard let joint = jointMap[jointName] else { continue }
            let point = denormalize(x: joint.x, y: joint.y, in: size)

            let labelRect = CGRect(
                x: point.x + 12,
                y: point.y - 20,
                width: 160,
                height: 36
            )

            // Background pill
            let pillPath = UIBezierPath(roundedRect: labelRect, cornerRadius: 8)
            context.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
            context.addPath(pillPath.cgPath)
            context.fillPath()

            // Text
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: uiColor(theme.angleAnnotation),
            ]
            let nsString = label as NSString
            nsString.draw(
                in: labelRect.insetBy(dx: 8, dy: 8),
                withAttributes: attrs
            )
        }
    }

    // MARK: - Trajectory Line

    func drawTrajectoryLine(
        on image: UIImage,
        frames: [FramePoseData],
        jointName: String = "right_wrist"
    ) -> UIImage {
        let size = image.size

        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        image.draw(at: .zero)
        guard let context = UIGraphicsGetCurrentContext() else { return image }

        let points = frames.compactMap { frame -> CGPoint? in
            guard let joint = frame.joints.first(where: { $0.name == jointName }) else { return nil }
            return denormalize(x: joint.x, y: joint.y, in: size)
        }

        guard points.count >= 2 else {
            UIGraphicsEndImageContext()
            return image
        }

        context.setStrokeColor(uiColor(theme.trajectoryLine).cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setShadow(offset: .zero, blur: 6, color: uiColor(theme.trajectoryLine).withAlphaComponent(0.5).cgColor)

        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()

        let resultImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resultImage
    }

    // MARK: - Swing Path

    func drawSwingPath(
        on image: UIImage,
        pathPoints: [[Double]],
        planeAngle: Double?,
        annotations: [PathAnnotation]?
    ) -> UIImage {
        let size = image.size

        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        image.draw(at: .zero)
        guard let context = UIGraphicsGetCurrentContext() else { return image }

        let points = pathPoints.compactMap { coord -> CGPoint? in
            guard coord.count >= 2 else { return nil }
            return denormalize(x: coord[0], y: coord[1], in: size)
        }

        guard points.count >= 2 else {
            UIGraphicsEndImageContext()
            return image
        }

        if let angle = planeAngle {
            drawSwingPlaneReference(context: context, angle: angle, size: size)
        }

        let pathColor = uiColor(theme.success)
        context.setStrokeColor(pathColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(8.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setShadow(offset: .zero, blur: 12, color: pathColor.withAlphaComponent(0.4).cgColor)

        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()

        context.setShadow(offset: .zero, blur: 0)
        context.setStrokeColor(pathColor.cgColor)
        context.setLineWidth(3.0)
        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()

        let resultImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resultImage
    }

    private func drawSwingPlaneReference(context: CGContext, angle: Double, size: CGSize) {
        let centerX = size.width * 0.5
        let centerY = size.height * 0.5
        let length = max(size.width, size.height)
        let radians = angle * .pi / 180.0

        let dx = cos(radians) * length * 0.5
        let dy = sin(radians) * length * 0.5

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.15).cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [6, 4])

        context.move(to: CGPoint(x: centerX - dx, y: centerY + dy))
        context.addLine(to: CGPoint(x: centerX + dx, y: centerY - dy))
        context.strokePath()

        context.setLineDash(phase: 0, lengths: [])
    }

    // MARK: - Pro Ghost Overlay

    func drawProGhost(
        on image: UIImage,
        proJoints: [JointData],
        opacity: CGFloat = 0.4
    ) -> UIImage {
        let size = image.size

        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        image.draw(at: .zero)
        guard let context = UIGraphicsGetCurrentContext() else { return image }

        let jointMap = Dictionary(uniqueKeysWithValues: proJoints.map { ($0.name, $0) })
        let ghostColor = UIColor(red: 0.83, green: 0.58, blue: 0.16, alpha: opacity)

        for (startName, endName) in Self.boneConnections {
            guard let start = jointMap[startName], let end = jointMap[endName] else { continue }

            let startPoint = denormalize(x: start.x, y: start.y, in: size)
            let endPoint = denormalize(x: end.x, y: end.y, in: size)

            context.setStrokeColor(ghostColor.cgColor)
            context.setLineWidth(2.5)
            context.setLineCap(.round)
            context.setShadow(offset: .zero, blur: 6, color: ghostColor.withAlphaComponent(0.3).cgColor)

            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }

        context.setShadow(offset: .zero, blur: 0)

        for joint in proJoints {
            let point = denormalize(x: joint.x, y: joint.y, in: size)
            context.setFillColor(ghostColor.cgColor)
            context.fillEllipse(in: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
        }

        let resultImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resultImage
    }

    // MARK: - Helpers

    private func denormalize(x: Double, y: Double, in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: (1.0 - y) * size.height)
    }

    private func uiColor(_ color: Color) -> UIColor {
        UIColor(color)
    }
}
