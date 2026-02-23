import Foundation
import Vision

/// Raw pose data extracted from a single video frame
struct FramePoseData: Codable {
    let frameIndex: Int
    let timestamp: Double
    let joints: [JointData]
    let confidence: Float

    enum CodingKeys: String, CodingKey {
        case frameIndex = "frame_index"
        case timestamp
        case joints
        case confidence
    }
}

struct JointData: Codable {
    let name: String
    let x: Double
    let y: Double
    let confidence: Float
}

/// Aggregated pose data for an entire session, ready to send to API
struct SessionPosePayload: Codable {
    let sessionID: String
    let durationSeconds: Int
    let fps: Int
    let frames: [FramePoseData]
    let keyFrameTimestamps: [Double]
    let skillLevel: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case durationSeconds = "duration_seconds"
        case fps
        case frames
        case keyFrameTimestamps = "key_frame_timestamps"
        case skillLevel = "skill_level"
    }
}

/// Maps Vision framework joint names to our canonical names
enum JointMapping {
    static func canonicalName(for joint: VNHumanBodyPoseObservation.JointName) -> String {
        switch joint {
        case .nose: return "nose"
        case .leftEye: return "left_eye"
        case .rightEye: return "right_eye"
        case .leftEar: return "left_ear"
        case .rightEar: return "right_ear"
        case .leftShoulder: return "left_shoulder"
        case .rightShoulder: return "right_shoulder"
        case .leftElbow: return "left_elbow"
        case .rightElbow: return "right_elbow"
        case .leftWrist: return "left_wrist"
        case .rightWrist: return "right_wrist"
        case .leftHip: return "left_hip"
        case .rightHip: return "right_hip"
        case .leftKnee: return "left_knee"
        case .rightKnee: return "right_knee"
        case .leftAnkle: return "left_ankle"
        case .rightAnkle: return "right_ankle"
        default: return "unknown"
        }
    }

    static let allJoints: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .leftEye, .rightEye, .leftEar, .rightEar,
        .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
        .leftWrist, .rightWrist, .leftHip, .rightHip,
        .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
    ]
}
