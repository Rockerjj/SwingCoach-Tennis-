import Foundation
import Vision
import CoreVideo

/// Apple Vision implementation — the shipping default. 17 joints, on-device,
/// confidence thresholded at `AppConstants.Analysis.poseConfidenceThreshold`.
final class VisionPoseEngine: PoseEngine {
    let identifier = PoseEngineKind.vision.rawValue

    private let processingQueue = DispatchQueue(label: "com.tennisiq.pose.vision", qos: .userInitiated)

    func extract(from pixelBuffer: CVPixelBuffer, frameIndex: Int, timestamp: Double) async throws -> FramePoseData? {
        let joints = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[JointData], Error>) in
            processingQueue.async {
                do {
                    let request = VNDetectHumanBodyPoseRequest()
                    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                    try handler.perform([request])

                    guard let observation = request.results?.first else {
                        continuation.resume(returning: [])
                        return
                    }

                    var joints: [JointData] = []
                    for jointName in JointMapping.allJoints {
                        guard let point = try? observation.recognizedPoint(jointName),
                              point.confidence > AppConstants.Analysis.poseConfidenceThreshold else { continue }

                        joints.append(JointData(
                            name: JointMapping.canonicalName(for: jointName),
                            x: Double(point.location.x),
                            y: Double(point.location.y),
                            confidence: point.confidence
                        ))
                    }

                    continuation.resume(returning: joints)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        guard joints.count >= 8 else { return nil }

        let avgConfidence = joints.map(\.confidence).reduce(0, +) / Float(joints.count)

        return FramePoseData(
            frameIndex: frameIndex,
            timestamp: timestamp,
            joints: joints,
            confidence: avgConfidence
        )
    }
}
