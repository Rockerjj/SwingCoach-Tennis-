import Foundation
import Combine

struct LiveFeedbackEvent: Identifiable {
    let id = UUID()
    let phase: SwingPhase
    let issue: String
    let severity: ZoneStatus
    let cueText: String
    let timestamp: Date
}

private struct IdealZone {
    let joint: String
    let angleMin: Double
    let angleMax: Double
    let issueKey: String
}

final class LiveSwingAnalyzer: ObservableObject {
    @Published var latestFeedback: LiveFeedbackEvent?
    @Published var currentPhase: SwingPhase = .readyPosition
    @Published var currentFormGrade: String? = nil

    var deviationThreshold: Double = 12
    var minConfidence: Float = 0.4

    private var frameHistory: [FramePoseData] = []
    private let maxHistory = 15
    private var lastEmitTime: Date = .distantPast
    private let emitCooldown: TimeInterval = 2.0

    private let phaseZones: [SwingPhase: [IdealZone]] = [
        .readyPosition: [
            IdealZone(joint: "knee_angle", angleMin: 150, angleMax: 175, issueKey: "knees_bent"),
            IdealZone(joint: "hip_angle", angleMin: 160, angleMax: 180, issueKey: "weight_forward"),
        ],
        .unitTurn: [
            IdealZone(joint: "shoulder_rotation", angleMin: 30, angleMax: 60, issueKey: "shoulders_early"),
            IdealZone(joint: "hip_rotation", angleMin: 20, angleMax: 50, issueKey: "hips_coiled"),
        ],
        .backswing: [
            IdealZone(joint: "elbow_angle", angleMin: 90, angleMax: 120, issueKey: "elbow_up"),
            IdealZone(joint: "wrist_angle", angleMin: 80, angleMax: 110, issueKey: "wrist_lag"),
        ],
        .forwardSwing: [
            IdealZone(joint: "elbow_angle", angleMin: 140, angleMax: 175, issueKey: "extend_arm"),
            IdealZone(joint: "hip_lead", angleMin: 20, angleMax: 50, issueKey: "hip_lead"),
        ],
        .contactPoint: [
            IdealZone(joint: "arm_extension", angleMin: 165, angleMax: 180, issueKey: "contact_front"),
            IdealZone(joint: "wrist_angle", angleMin: 170, angleMax: 185, issueKey: "firm_wrist"),
        ],
        .followThrough: [
            IdealZone(joint: "arm_angle", angleMin: 90, angleMax: 140, issueKey: "finish_high"),
            IdealZone(joint: "body_rotation", angleMin: 60, angleMax: 120, issueKey: "rotate_through"),
        ],
        .recovery: [
            IdealZone(joint: "knee_angle", angleMin: 150, angleMax: 175, issueKey: "split_step"),
        ],
    ]

    private let phaseCues: [String: String] = [
        "weight_forward": "Shift weight to balls of feet",
        "knees_bent": "Bend your knees more",
        "racket_up": "Keep racket in front",
        "shoulders_early": "Start shoulder turn earlier",
        "hips_coiled": "Coil hips with shoulders",
        "racket_back": "Take racket back with turn",
        "elbow_up": "Keep elbow up on backswing",
        "wrist_lag": "Let wrist lag behind",
        "loop_complete": "Finish the backswing loop",
        "accelerate": "Accelerate through contact",
        "extend_arm": "Extend arm toward ball",
        "hip_lead": "Lead with hips",
        "contact_front": "Hit ball in front of body",
        "eyes_on_ball": "Keep eyes on ball",
        "firm_wrist": "Keep wrist firm at contact",
        "finish_high": "Finish over shoulder",
        "rotate_through": "Rotate body through",
        "balance": "Stay balanced",
        "split_step": "Split step for next",
        "return_ready": "Return to ready position",
    ]

    func processFrame(_ frame: FramePoseData) {
        frameHistory.append(frame)
        if frameHistory.count > maxHistory {
            frameHistory.removeFirst()
        }

        let detectedPhase = detectPhase(from: frameHistory)
        currentPhase = detectedPhase

        guard let zones = phaseZones[detectedPhase],
              frameHistory.count >= 3
        else { return }

        let joints = frame.joints
        let jointMap = Dictionary(uniqueKeysWithValues: joints.map { ($0.name, $0) })

        for zone in zones {
            guard let angle = computeAngle(for: zone.joint, joints: joints, jointMap: jointMap, history: frameHistory),
                  angle >= 0
            else { continue }

            let deviation = deviationFromZone(angle, min: zone.angleMin, max: zone.angleMax)
            if deviation > deviationThreshold {
                let severity = severityForDeviation(deviation)
                let cueText = phaseCues[zone.issueKey] ?? "Adjust \(zone.joint)"
                emitIfAllowed(phase: detectedPhase, issue: zone.issueKey, severity: severity, cueText: cueText)
                return
            }
        }
    }

    func reset() {
        frameHistory.removeAll()
        currentPhase = .readyPosition
        latestFeedback = nil
        lastEmitTime = .distantPast
    }

    private func detectPhase(from history: [FramePoseData]) -> SwingPhase {
        guard history.count >= 3 else { return .readyPosition }

        let recent = history.suffix(5)
        let velocities = computeWristVelocities(from: Array(recent))
        let accelerations = computeAccelerations(velocities)

        if let last = velocities.last, let prev = velocities.dropLast().last {
            if last > 0.08 && prev < 0.04 { return .forwardSwing }
            if last > 0.06 && accelerations.last ?? 0 < -0.02 { return .contactPoint }
            if last < -0.03 { return .backswing }
            if last > 0.02 && (velocities.first ?? 0) < 0.01 { return .unitTurn }
        }

        let avgVel = velocities.isEmpty ? 0 : velocities.reduce(0, +) / Double(velocities.count)
        if abs(avgVel) < 0.02 { return .readyPosition }
        if avgVel > 0.03 { return .followThrough }
        return .recovery
    }

    private func computeWristVelocities(from frames: [FramePoseData]) -> [Double] {
        let wristName = Handedness.current.dominantWrist
        var result: [Double] = []
        for i in 1..<frames.count {
            let curr = frames[i].joints.first { $0.name == wristName }
            let prev = frames[i - 1].joints.first { $0.name == wristName }
            guard let c = curr, let p = prev, c.confidence >= minConfidence, p.confidence >= minConfidence else {
                result.append(0)
                continue
            }
            let dx = c.x - p.x
            let dy = c.y - p.y
            result.append(hypot(dx, dy))
        }
        return result
    }

    private func computeAccelerations(_ velocities: [Double]) -> [Double] {
        (1..<velocities.count).map { velocities[$0] - velocities[$0 - 1] }
    }

    private func computeAngle(
        for zoneJoint: String,
        joints: [JointData],
        jointMap: [String: JointData],
        history: [FramePoseData]
    ) -> Double? {
        switch zoneJoint {
        case "knee_angle":
            return angleBetween(
                jointMap["left_hip"], jointMap["left_knee"], jointMap["left_ankle"]
            ) ?? angleBetween(
                jointMap["right_hip"], jointMap["right_knee"], jointMap["right_ankle"]
            )
        case "hip_angle":
            return angleBetween(
                jointMap["left_shoulder"], jointMap["left_hip"], jointMap["left_knee"]
            ) ?? angleBetween(
                jointMap["right_shoulder"], jointMap["right_hip"], jointMap["right_knee"]
            )
        case "elbow_angle":
            return angleBetween(
                jointMap["left_shoulder"], jointMap["left_elbow"], jointMap["left_wrist"]
            ) ?? angleBetween(
                jointMap["right_shoulder"], jointMap["right_elbow"], jointMap["right_wrist"]
            )
        case "wrist_angle":
            return angleBetween(
                jointMap["right_elbow"], jointMap["right_wrist"], jointMap["right_shoulder"]
            ) ?? angleBetween(
                jointMap["left_elbow"], jointMap["left_wrist"], jointMap["left_shoulder"]
            )
        case "shoulder_rotation":
            return shoulderRotationAngle(jointMap)
        case "hip_rotation":
            return hipRotationAngle(jointMap)
        case "arm_extension", "arm_angle":
            return angleBetween(
                jointMap["right_shoulder"], jointMap["right_elbow"], jointMap["right_wrist"]
            ) ?? angleBetween(
                jointMap["left_shoulder"], jointMap["left_elbow"], jointMap["left_wrist"]
            )
        case "hip_lead", "body_rotation":
            return shoulderRotationAngle(jointMap)
        default:
            return nil
        }
    }

    private func angleBetween(_ a: JointData?, _ b: JointData?, _ c: JointData?) -> Double? {
        guard let a = a, let b = b, let c = c,
              a.confidence >= minConfidence, b.confidence >= minConfidence, c.confidence >= minConfidence
        else { return nil }
        let ba = (ax: a.x - b.x, ay: a.y - b.y)
        let bc = (cx: c.x - b.x, cy: c.y - b.y)
        let dot = ba.ax * bc.cx + ba.ay * bc.cy
        let cross = ba.ax * bc.cy - ba.ay * bc.cx
        let angle = atan2(cross, dot) * 180 / .pi
        return angle >= 0 ? angle : angle + 360
    }

    private func shoulderRotationAngle(_ map: [String: JointData]) -> Double? {
        guard let l = map["left_shoulder"], let r = map["right_shoulder"],
              let nose = map["nose"],
              l.confidence >= minConfidence, r.confidence >= minConfidence, nose.confidence >= minConfidence
        else { return nil }
        let midX = (l.x + r.x) / 2
        let dx = r.x - l.x
        let dy = r.y - l.y
        let angle = atan2(dy, dx) * 180 / .pi
        return angle >= 0 ? angle : angle + 360
    }

    private func hipRotationAngle(_ map: [String: JointData]) -> Double? {
        guard let l = map["left_hip"], let r = map["right_hip"],
              l.confidence >= minConfidence, r.confidence >= minConfidence
        else { return nil }
        let dx = r.x - l.x
        let dy = r.y - l.y
        let angle = atan2(dy, dx) * 180 / .pi
        return angle >= 0 ? angle : angle + 360
    }

    private func deviationFromZone(_ angle: Double, min minA: Double, max maxA: Double) -> Double {
        if angle >= minA && angle <= maxA { return 0 }
        if angle < minA { return minA - angle }
        return angle - maxA
    }

    private func severityForDeviation(_ deviation: Double) -> ZoneStatus {
        if deviation > deviationThreshold * 2 { return .outOfZone }
        if deviation > deviationThreshold { return .warning }
        return .inZone
    }

    private func emitIfAllowed(phase: SwingPhase, issue: String, severity: ZoneStatus, cueText: String) {
        let now = Date()
        guard now.timeIntervalSince(lastEmitTime) >= emitCooldown else { return }
        lastEmitTime = now
        let event = LiveFeedbackEvent(phase: phase, issue: issue, severity: severity, cueText: cueText, timestamp: now)
        DispatchQueue.main.async { [weak self] in
            self?.latestFeedback = event
        }
    }
}
