import Foundation

struct DetectedStroke: Codable {
    let type: String
    let contactTimestamp: Double
    let phases: [String: DetectedPhase]
}

struct DetectedPhase: Codable {
    let timestamp: Double
    let angles: [String: MeasuredAngle]
}

struct MeasuredAngle: Codable {
    let value: Double
    let label: String
    let visible: Bool

    enum CodingKeys: String, CodingKey {
        case value, label, visible
    }
}

final class StrokeDetector {
    private let minConfidence: Float = 0.3
    private let minTimeBetweenStrokes: Double = 2.0
    private let velocityThreshold: Double = 0.025
    private let handedness: Handedness

    init(handedness: Handedness = .current) {
        self.handedness = handedness
    }

    func detectStrokes(frames: [FramePoseData]) -> [DetectedStroke] {
        guard frames.count >= 10 else { return [] }

        let sorted = frames.sorted { $0.timestamp < $1.timestamp }
        let velocities = computeWristVelocities(sorted)
        let contactIndices = findContactPeaks(velocities: velocities, frames: sorted)

        return contactIndices.compactMap { contactIdx in
            buildStroke(contactIndex: contactIdx, frames: sorted, velocities: velocities)
        }
    }

    private func computeWristVelocities(_ frames: [FramePoseData]) -> [Double] {
        let wristName = handedness.dominantWrist
        var velocities: [Double] = [0]

        for i in 1..<frames.count {
            let curr = frames[i].joints.first { $0.name == wristName && $0.confidence >= minConfidence }
            let prev = frames[i - 1].joints.first { $0.name == wristName && $0.confidence >= minConfidence }

            guard let c = curr, let p = prev else {
                velocities.append(0)
                continue
            }

            let dt = frames[i].timestamp - frames[i - 1].timestamp
            guard dt > 0 else {
                velocities.append(0)
                continue
            }

            let dist = hypot(c.x - p.x, c.y - p.y)
            velocities.append(dist / dt)
        }

        return smoothVelocities(velocities, windowSize: 3)
    }

    private func smoothVelocities(_ v: [Double], windowSize: Int) -> [Double] {
        guard v.count >= windowSize else { return v }
        let half = windowSize / 2
        return v.indices.map { i in
            let lo = max(0, i - half)
            let hi = min(v.count - 1, i + half)
            let slice = v[lo...hi]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    private func findContactPeaks(velocities: [Double], frames: [FramePoseData]) -> [Int] {
        guard velocities.count >= 5 else { return [] }

        let avgVelocity = velocities.reduce(0, +) / Double(velocities.count)
        let dynamicThreshold = max(velocityThreshold, avgVelocity * 2.0)

        var peaks: [Int] = []
        var lastPeakTimestamp: Double = -100

        for i in 2..<(velocities.count - 2) {
            let isPeak = velocities[i] > velocities[i - 1] &&
                         velocities[i] > velocities[i - 2] &&
                         velocities[i] >= velocities[i + 1] &&
                         velocities[i] > dynamicThreshold

            let timeSinceLast = frames[i].timestamp - lastPeakTimestamp

            if isPeak && timeSinceLast > minTimeBetweenStrokes {
                peaks.append(i)
                lastPeakTimestamp = frames[i].timestamp
            }
        }

        return peaks
    }

    private func buildStroke(contactIndex: Int, frames: [FramePoseData], velocities: [Double]) -> DetectedStroke? {
        let contactFrame = frames[contactIndex]
        let contactTime = contactFrame.timestamp

        let forwardSwingIdx = scanBackward(from: contactIndex, frames: frames, velocities: velocities, condition: { v in v < velocities[contactIndex] * 0.5 })
        let backswingIdx = scanBackward(from: forwardSwingIdx, frames: frames, velocities: velocities, condition: { v in v < 0.01 })
        let unitTurnIdx = scanBackwardForShoulderChange(from: backswingIdx, frames: frames)
        let readyIdx = scanBackward(from: unitTurnIdx, frames: frames, velocities: velocities, condition: { v in v < 0.005 })
        let followThroughIdx = scanForward(from: contactIndex, frames: frames, velocities: velocities, condition: { v in v < velocities[contactIndex] * 0.3 })
        let recoveryIdx = scanForward(from: followThroughIdx, frames: frames, velocities: velocities, condition: { v in v < 0.01 })

        let readyTime = frames[readyIdx].timestamp
        let unitTurnTime = frames[unitTurnIdx].timestamp
        let backswingTime = frames[backswingIdx].timestamp
        let forwardSwingTime = frames[forwardSwingIdx].timestamp
        let followThroughTime = frames[followThroughIdx].timestamp
        let recoveryTime = frames[recoveryIdx].timestamp

        guard readyTime < unitTurnTime,
              unitTurnTime <= backswingTime,
              backswingTime <= forwardSwingTime,
              forwardSwingTime < contactTime,
              contactTime < followThroughTime,
              followThroughTime <= recoveryTime
        else {
            let fallbackPhases = buildFallbackPhases(contactTime: contactTime, contactFrame: contactFrame)
            let strokeType = inferStrokeType(at: contactIndex, frames: frames)
            return DetectedStroke(type: strokeType, contactTimestamp: contactTime, phases: fallbackPhases)
        }

        let phaseFrames: [(String, Int, Double)] = [
            ("ready_position", readyIdx, readyTime),
            ("unit_turn", unitTurnIdx, unitTurnTime),
            ("backswing", backswingIdx, backswingTime),
            ("forward_swing", forwardSwingIdx, forwardSwingTime),
            ("contact_point", contactIndex, contactTime),
            ("follow_through", followThroughIdx, followThroughTime),
            ("recovery", recoveryIdx, recoveryTime),
        ]

        var phases: [String: DetectedPhase] = [:]
        for (name, idx, time) in phaseFrames {
            let angles = measureAngles(frame: frames[idx])
            phases[name] = DetectedPhase(timestamp: time, angles: angles)
        }

        let strokeType = inferStrokeType(at: contactIndex, frames: frames)
        return DetectedStroke(type: strokeType, contactTimestamp: contactTime, phases: phases)
    }

    private func buildFallbackPhases(contactTime: Double, contactFrame: FramePoseData) -> [String: DetectedPhase] {
        let offsets: [(String, Double)] = [
            ("ready_position", -1.5),
            ("unit_turn", -1.2),
            ("backswing", -0.8),
            ("forward_swing", -0.4),
            ("contact_point", 0),
            ("follow_through", 0.3),
            ("recovery", 0.8),
        ]

        var phases: [String: DetectedPhase] = [:]
        let angles = measureAngles(frame: contactFrame)
        for (name, offset) in offsets {
            phases[name] = DetectedPhase(timestamp: max(0, contactTime + offset), angles: angles)
        }
        return phases
    }

    private func scanBackward(from startIdx: Int, frames: [FramePoseData], velocities: [Double], condition: (Double) -> Bool) -> Int {
        var idx = startIdx
        while idx > 0 {
            idx -= 1
            if condition(velocities[idx]) { return idx }
        }
        return max(0, startIdx - 3)
    }

    private func scanForward(from startIdx: Int, frames: [FramePoseData], velocities: [Double], condition: (Double) -> Bool) -> Int {
        var idx = startIdx
        while idx < frames.count - 1 {
            idx += 1
            if condition(velocities[idx]) { return idx }
        }
        return min(frames.count - 1, startIdx + 3)
    }

    private func scanBackwardForShoulderChange(from startIdx: Int, frames: [FramePoseData]) -> Int {
        var idx = startIdx
        let startRotation = shoulderRotation(frame: frames[startIdx])

        while idx > 0 {
            idx -= 1
            let rotation = shoulderRotation(frame: frames[idx])
            if let sr = startRotation, let cr = rotation, abs(sr - cr) > 10 {
                return idx
            }
        }
        return max(0, startIdx - 2)
    }

    private func shoulderRotation(frame: FramePoseData) -> Double? {
        let map = Dictionary(uniqueKeysWithValues: frame.joints.map { ($0.name, $0) })
        guard let ls = map["left_shoulder"], let rs = map["right_shoulder"],
              ls.confidence >= minConfidence, rs.confidence >= minConfidence else { return nil }
        let dx = rs.x - ls.x
        let dy = rs.y - ls.y
        return atan2(abs(dy), abs(dx)) * 180 / .pi
    }

    private func inferStrokeType(at idx: Int, frames: [FramePoseData]) -> String {
        let frame = frames[idx]
        let map = Dictionary(uniqueKeysWithValues: frame.joints.map { ($0.name, $0) })

        let wristName = handedness.dominantWrist
        guard let wrist = map[wristName],
              let nose = map["nose"],
              wrist.confidence >= minConfidence,
              nose.confidence >= minConfidence else {
            return "forehand"
        }

        if wrist.y > nose.y + 0.15 {
            return "serve"
        }

        let isRight = handedness == .right
        let midX = ((map["left_shoulder"]?.x ?? 0.5) + (map["right_shoulder"]?.x ?? 0.5)) / 2

        if isRight {
            return wrist.x > midX ? "forehand" : "backhand"
        } else {
            return wrist.x < midX ? "forehand" : "backhand"
        }
    }

    func measureAngles(frame: FramePoseData) -> [String: MeasuredAngle] {
        let map = Dictionary(uniqueKeysWithValues: frame.joints.map { ($0.name, $0) })
        let side = handedness == .right ? "right" : "left"
        let otherSide = handedness == .right ? "left" : "right"

        var angles: [String: MeasuredAngle] = [:]

        if let a = computeAngle(a: map["\(side)_shoulder"], b: map["\(side)_elbow"], c: map["\(side)_wrist"]) {
            angles["elbow_angle"] = MeasuredAngle(value: round(a), label: "Elbow: \(Int(a))°", visible: true)
        } else {
            angles["elbow_angle"] = MeasuredAngle(value: 0, label: "Elbow: NOT_VISIBLE", visible: false)
        }

        if let a = computeAngle(a: map["\(side)_hip"], b: map["\(side)_knee"], c: map["\(side)_ankle"]) {
            angles["knee_angle"] = MeasuredAngle(value: round(a), label: "Knee: \(Int(a))°", visible: true)
        } else {
            angles["knee_angle"] = MeasuredAngle(value: 0, label: "Knee: NOT_VISIBLE", visible: false)
        }

        if let a = computeAngle(a: map["\(side)_shoulder"], b: map["\(side)_hip"], c: map["\(side)_knee"]) {
            angles["hip_angle"] = MeasuredAngle(value: round(a), label: "Hip: \(Int(a))°", visible: true)
        } else {
            angles["hip_angle"] = MeasuredAngle(value: 0, label: "Hip: NOT_VISIBLE", visible: false)
        }

        if let ls = map["left_shoulder"], let rs = map["right_shoulder"],
           let lh = map["left_hip"], let rh = map["right_hip"],
           ls.confidence >= minConfidence, rs.confidence >= minConfidence,
           lh.confidence >= minConfidence, rh.confidence >= minConfidence {
            let shoulderDx = rs.x - ls.x
            let shoulderDy = rs.y - ls.y
            let hipDx = rh.x - lh.x
            let hipDy = rh.y - lh.y
            let shoulderAngle = atan2(shoulderDy, shoulderDx)
            let hipAngle = atan2(hipDy, hipDx)
            let rotation = abs(shoulderAngle - hipAngle) * 180 / .pi
            angles["shoulder_rotation"] = MeasuredAngle(value: round(rotation), label: "Shoulder rotation: \(Int(rotation))°", visible: true)
        } else {
            angles["shoulder_rotation"] = MeasuredAngle(value: 0, label: "Shoulder rotation: NOT_VISIBLE", visible: false)
        }

        if let shoulder = map["\(side)_shoulder"], let wrist = map["\(side)_wrist"],
           shoulder.confidence >= minConfidence, wrist.confidence >= minConfidence {
            let ext = hypot(wrist.x - shoulder.x, wrist.y - shoulder.y)
            let normalized = min(180, ext * 500)
            angles["arm_extension"] = MeasuredAngle(value: round(normalized), label: "Arm extension: \(Int(normalized))°", visible: true)
        } else {
            angles["arm_extension"] = MeasuredAngle(value: 0, label: "Arm extension: NOT_VISIBLE", visible: false)
        }

        return angles
    }

    private func computeAngle(a: JointData?, b: JointData?, c: JointData?) -> Double? {
        guard let a = a, let b = b, let c = c,
              a.confidence >= minConfidence, b.confidence >= minConfidence, c.confidence >= minConfidence
        else { return nil }

        let ba = (x: a.x - b.x, y: a.y - b.y)
        let bc = (x: c.x - b.x, y: c.y - b.y)
        let dot = ba.x * bc.x + ba.y * bc.y
        let magBA = hypot(ba.x, ba.y)
        let magBC = hypot(bc.x, bc.y)
        guard magBA > 0, magBC > 0 else { return nil }

        let cosAngle = max(-1, min(1, dot / (magBA * magBC)))
        return acos(cosAngle) * 180 / .pi
    }
}
