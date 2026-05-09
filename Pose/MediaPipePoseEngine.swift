import Foundation
import CoreVideo

#if canImport(MediaPipeTasksVision)
import MediaPipeTasksVision

/// MediaPipe Pose Landmarker implementation. Emits all 33 BlazePose keypoints —
/// the legacy 17-joint COCO schema is a strict subset, so anything that consumed
/// the old set (StrokeDetector, OverlayRenderer) keeps working. Hosted-LLM
/// labelers consume the full 33-keypoint trajectory in the backend.
///
/// Y-axis note: MediaPipe uses top-left origin (y=0 at top). Our schema follows
/// Vision's bottom-left origin (y=0 at bottom) — we flip y on conversion so
/// overlays render identically regardless of which engine produced the frame.
final class MediaPipePoseEngine: PoseEngine {
    let identifier = PoseEngineKind.mediapipe.rawValue

    private var landmarker: PoseLandmarker?
    private let modelName: String

    init(modelName: String = "pose_landmarker_full") {
        self.modelName = modelName
    }

    func warmUp() throws {
        _ = try ensureLandmarker()
    }

    private func ensureLandmarker() throws -> PoseLandmarker {
        if let landmarker { return landmarker }

        guard let modelPath = Bundle.main.path(forResource: modelName, ofType: "task") else {
            throw NSError(
                domain: "MediaPipePoseEngine",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "\(modelName).task not found in app bundle"]
            )
        }

        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .video
        options.numPoses = 1
        options.minPoseDetectionConfidence = 0.5
        options.minPosePresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5

        let new = try PoseLandmarker(options: options)
        landmarker = new
        return new
    }

    func extract(from pixelBuffer: CVPixelBuffer, frameIndex: Int, timestamp: Double) async throws -> FramePoseData? {
        let landmarker = try ensureLandmarker()
        let image = try MPImage(pixelBuffer: pixelBuffer)
        let timestampMs = Int(timestamp * 1000)

        let result = try landmarker.detect(videoFrame: image, timestampInMilliseconds: timestampMs)

        guard let landmarks = result.landmarks.first, landmarks.count == 33 else { return nil }

        var joints: [JointData] = []
        for (mpIndex, canonicalName) in Self.canonicalMapping {
            let landmark = landmarks[mpIndex]
            let visibility = landmark.visibility?.floatValue ?? 0

            guard visibility > AppConstants.Analysis.poseConfidenceThreshold else { continue }

            joints.append(JointData(
                name: canonicalName,
                x: Double(landmark.x),
                y: 1.0 - Double(landmark.y),  // flip to bottom-left origin
                confidence: visibility
            ))
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

    // MARK: - Full 33-keypoint MediaPipe BlazePose schema
    //
    // The legacy 17-joint COCO schema is a strict subset of these names; the
    // first 17 entries in `canonicalMapping` are name-compatible with what
    // VisionPoseEngine emits, so StrokeDetector / OverlayRenderer work without
    // change. The additional 16 keypoints (extra eye points, mouth, hands,
    // feet) flow through to the backend payload for the hosted labeler.

    private static let canonicalMapping: [(Int, String)] = [
        // Face
        (0,  "nose"),
        (1,  "left_eye_inner"),
        (2,  "left_eye"),
        (3,  "left_eye_outer"),
        (4,  "right_eye_inner"),
        (5,  "right_eye"),
        (6,  "right_eye_outer"),
        (7,  "left_ear"),
        (8,  "right_ear"),
        (9,  "mouth_left"),
        (10, "mouth_right"),
        // Upper body
        (11, "left_shoulder"),
        (12, "right_shoulder"),
        (13, "left_elbow"),
        (14, "right_elbow"),
        (15, "left_wrist"),
        (16, "right_wrist"),
        // Hands (the racket-side detail the heuristic was missing)
        (17, "left_pinky"),
        (18, "right_pinky"),
        (19, "left_index"),
        (20, "right_index"),
        (21, "left_thumb"),
        (22, "right_thumb"),
        // Lower body
        (23, "left_hip"),
        (24, "right_hip"),
        (25, "left_knee"),
        (26, "right_knee"),
        (27, "left_ankle"),
        (28, "right_ankle"),
        (29, "left_heel"),
        (30, "right_heel"),
        (31, "left_foot_index"),
        (32, "right_foot_index"),
    ]
}
#else
/// Build-time fallback used when the CocoaPods MediaPipe module is unavailable.
/// This keeps the app shippable from the Xcode project while the workspace/pod
/// integration is being repaired; runtime pose extraction still works via Vision.
final class MediaPipePoseEngine: PoseEngine {
    let identifier = PoseEngineKind.vision.rawValue

    private let fallback = VisionPoseEngine()

    init(modelName: String = "pose_landmarker_full") {}

    func extract(from pixelBuffer: CVPixelBuffer, frameIndex: Int, timestamp: Double) async throws -> FramePoseData? {
        try await fallback.extract(from: pixelBuffer, frameIndex: frameIndex, timestamp: timestamp)
    }
}
#endif
