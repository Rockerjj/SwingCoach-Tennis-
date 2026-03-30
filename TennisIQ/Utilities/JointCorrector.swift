import Foundation

enum JointCorrector {
    /// Compute corrected joint positions by adjusting angles toward ideal values.
    /// Returns a new array of JointData with corrected positions for the specified angles.
    static func computeCorrectedJoints(
        userJoints: [JointData],
        corrections: [String: Double]
    ) -> [JointData] {
        var jointMap = Dictionary(uniqueKeysWithValues: userJoints.map { ($0.name, $0) })

        for chain in SkeletonTopology.jointChains {
            guard let targetAngle = corrections[chain.angleKey],
                  let parent = jointMap[chain.parent],
                  let joint = jointMap[chain.joint],
                  let child = jointMap[chain.child],
                  parent.confidence > 0.2,
                  joint.confidence > 0.2,
                  child.confidence > 0.2
            else { continue }

            let currentAngle = computeAngle(a: parent, b: joint, c: child)
            guard let current = currentAngle else { continue }

            let delta = targetAngle - current
            guard abs(delta) > 1.0 else { continue }

            let rotated = rotatePoint(
                point: (x: child.x, y: child.y),
                pivot: (x: joint.x, y: joint.y),
                angleDegrees: -delta
            )

            jointMap[chain.child] = JointData(
                name: child.name,
                x: rotated.x,
                y: rotated.y,
                confidence: child.confidence
            )
        }

        return userJoints.map { jointMap[$0.name] ?? $0 }
    }

    /// Interpolate between two joint arrays. lerpFactor 0.0 = from, 1.0 = to.
    static func interpolateJoints(
        from: [JointData],
        to: [JointData],
        factor: Double
    ) -> [JointData] {
        let toMap = Dictionary(uniqueKeysWithValues: to.map { ($0.name, $0) })
        let t = max(0, min(1, factor))

        return from.map { joint in
            guard let target = toMap[joint.name] else { return joint }
            return JointData(
                name: joint.name,
                x: joint.x + (target.x - joint.x) * t,
                y: joint.y + (target.y - joint.y) * t,
                confidence: joint.confidence
            )
        }
    }

    /// Color for the current lerp factor: red (0.0) -> yellow (0.5) -> green (1.0)
    static func correctionColor(factor: Double) -> (r: Double, g: Double, b: Double) {
        let t = max(0, min(1, factor))
        if t < 0.5 {
            let p = t / 0.5
            return (r: 1.0, g: p * 0.9, b: 0.0)
        } else {
            let p = (t - 0.5) / 0.5
            return (r: 1.0 - p * 0.7, g: 0.9 + p * 0.1, b: p * 0.3)
        }
    }

    private static func computeAngle(a: JointData, b: JointData, c: JointData) -> Double? {
        let ba = (x: a.x - b.x, y: a.y - b.y)
        let bc = (x: c.x - b.x, y: c.y - b.y)
        let dot = ba.x * bc.x + ba.y * bc.y
        let magBA = hypot(ba.x, ba.y)
        let magBC = hypot(bc.x, bc.y)
        guard magBA > 0, magBC > 0 else { return nil }
        let cosAngle = max(-1, min(1, dot / (magBA * magBC)))
        return acos(cosAngle) * 180 / .pi
    }

    private static func rotatePoint(
        point: (x: Double, y: Double),
        pivot: (x: Double, y: Double),
        angleDegrees: Double
    ) -> (x: Double, y: Double) {
        let rad = angleDegrees * .pi / 180
        let dx = point.x - pivot.x
        let dy = point.y - pivot.y
        let cosA = cos(rad)
        let sinA = sin(rad)
        return (
            x: pivot.x + dx * cosA - dy * sinA,
            y: pivot.y + dx * sinA + dy * cosA
        )
    }
}
