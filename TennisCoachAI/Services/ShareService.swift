import UIKit
import AVFoundation
import CoreGraphics

final class ShareService {
    static let shared = ShareService()
    private init() {}

    func generateShareImage(
        grade: String,
        strokeType: String,
        joints: [JointData],
        videoSize: CGSize
    ) -> UIImage? {
        let canvasSize = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { ctx in
            let context = ctx.cgContext

            UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            drawSkeletonOverlay(context: context, joints: joints, canvasSize: canvasSize, videoSize: videoSize)
            drawGradeBadge(context: context, grade: grade, canvasSize: canvasSize)
            drawStrokeLabel(context: context, strokeType: strokeType, canvasSize: canvasSize)
            drawWatermark(context: context, canvasSize: canvasSize)
        }
    }

    private func drawSkeletonOverlay(context: CGContext, joints: [JointData], canvasSize: CGSize, videoSize: CGSize) {
        let headJoints: Set<String> = ["nose", "left_eye", "right_eye", "left_ear", "right_ear"]
        let bodyJoints = joints.filter { !headJoints.contains($0.name) }

        let bones: [(String, String)] = [
            ("left_shoulder", "right_shoulder"),
            ("left_shoulder", "left_elbow"), ("left_elbow", "left_wrist"),
            ("right_shoulder", "right_elbow"), ("right_elbow", "right_wrist"),
            ("left_shoulder", "left_hip"), ("right_shoulder", "right_hip"),
            ("left_hip", "right_hip"),
            ("left_hip", "left_knee"), ("left_knee", "left_ankle"),
            ("right_hip", "right_knee"), ("right_knee", "right_ankle")
        ]

        let map = Dictionary(uniqueKeysWithValues: bodyJoints.map { ($0.name, $0) })

        let limeGreen = UIColor(red: 0.784, green: 1.0, blue: 0.0, alpha: 0.9)
        context.setStrokeColor(limeGreen.cgColor)
        context.setLineWidth(4.0)
        context.setLineCap(.round)

        for (a, b) in bones {
            guard let ja = map[a], let jb = map[b] else { continue }
            let ptA = toCanvas(ja, canvasSize: canvasSize)
            let ptB = toCanvas(jb, canvasSize: canvasSize)
            context.move(to: ptA)
            context.addLine(to: ptB)
        }
        context.strokePath()

        let dotColor = UIColor(red: 0.784, green: 1.0, blue: 0.0, alpha: 1.0)
        context.setFillColor(dotColor.cgColor)
        for joint in bodyJoints {
            let pt = toCanvas(joint, canvasSize: canvasSize)
            context.fillEllipse(in: CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12))
        }
    }

    private func toCanvas(_ joint: JointData, canvasSize: CGSize) -> CGPoint {
        CGPoint(
            x: joint.y * canvasSize.width,
            y: joint.x * canvasSize.height
        )
    }

    private func drawGradeBadge(context: CGContext, grade: String, canvasSize: CGSize) {
        let badgeSize: CGFloat = 120
        let padding: CGFloat = 40
        let badgeRect = CGRect(
            x: canvasSize.width - badgeSize - padding,
            y: padding,
            width: badgeSize,
            height: badgeSize
        )

        let gradeColor: UIColor = switch grade.prefix(1) {
        case "A": UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1)
        case "B": UIColor(red: 0.784, green: 1.0, blue: 0.0, alpha: 1)
        case "C": UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1)
        default: UIColor(red: 1.0, green: 0.36, blue: 0.36, alpha: 1)
        }

        context.setFillColor(gradeColor.withAlphaComponent(0.15).cgColor)
        let path = UIBezierPath(roundedRect: badgeRect, cornerRadius: 24)
        context.addPath(path.cgPath)
        context.fillPath()

        context.setStrokeColor(gradeColor.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(2)
        context.addPath(path.cgPath)
        context.strokePath()

        let gradeFont = UIFont.systemFont(ofSize: 56, weight: .black)
        let gradeAttrs: [NSAttributedString.Key: Any] = [
            .font: gradeFont,
            .foregroundColor: gradeColor
        ]
        let gradeString = NSString(string: grade)
        let gradeSize = gradeString.size(withAttributes: gradeAttrs)
        let gradeOrigin = CGPoint(
            x: badgeRect.midX - gradeSize.width / 2,
            y: badgeRect.midY - gradeSize.height / 2
        )
        gradeString.draw(at: gradeOrigin, withAttributes: gradeAttrs)
    }

    private func drawStrokeLabel(context: CGContext, strokeType: String, canvasSize: CGSize) {
        let font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        let string = NSString(string: strokeType.uppercased())
        let size = string.size(withAttributes: attrs)
        let origin = CGPoint(x: 40, y: 40)

        let bgRect = CGRect(x: origin.x - 12, y: origin.y - 6, width: size.width + 24, height: size.height + 12)
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 8)
        context.addPath(bgPath.cgPath)
        context.fillPath()

        string.draw(at: origin, withAttributes: attrs)
    }

    private func drawWatermark(context: CGContext, canvasSize: CGSize) {
        let watermarkFont = UIFont.systemFont(ofSize: 18, weight: .medium)
        let watermarkAttrs: [NSAttributedString.Key: Any] = [
            .font: watermarkFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.6)
        ]
        let watermarkText = NSString(string: "Analyzed by Tennis Coach AI")
        let watermarkSize = watermarkText.size(withAttributes: watermarkAttrs)
        let watermarkOrigin = CGPoint(
            x: canvasSize.width / 2 - watermarkSize.width / 2,
            y: canvasSize.height - watermarkSize.height - 60
        )

        let bgRect = CGRect(
            x: watermarkOrigin.x - 16,
            y: watermarkOrigin.y - 8,
            width: watermarkSize.width + 32,
            height: watermarkSize.height + 16
        )
        context.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 20)
        context.addPath(bgPath.cgPath)
        context.fillPath()

        watermarkText.draw(at: watermarkOrigin, withAttributes: watermarkAttrs)
    }

    func presentShareSheet(image: UIImage, from viewController: UIViewController) {
        let items: [Any] = [
            image,
            "My tennis stroke analyzed by AI! 🎾 Download Tennis Coach AI free on the App Store."
        ]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.excludedActivityTypes = [.addToReadingList, .assignToContact, .openInIBooks]
        viewController.present(activityVC, animated: true)
    }
}
