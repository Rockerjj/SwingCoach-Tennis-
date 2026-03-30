import Foundation

enum SkeletonTopology {
    static let bones: [(String, String)] = [
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

    /// Joint chains for IK correction (parent -> joint -> child)
    static let jointChains: [(parent: String, joint: String, child: String, angleKey: String)] = [
        ("right_shoulder", "right_elbow", "right_wrist", "elbow_angle"),
        ("left_shoulder", "left_elbow", "left_wrist", "elbow_angle"),
        ("right_hip", "right_knee", "right_ankle", "knee_angle"),
        ("left_hip", "left_knee", "left_ankle", "knee_angle"),
        ("right_shoulder", "right_hip", "right_knee", "hip_angle"),
        ("left_shoulder", "left_hip", "left_knee", "hip_angle"),
    ]
}

/// Parsed angle measurement with ideal range (used by SkeletonCorrectionView)
struct CorrectionAngle {
    let name: String
    let measured: Double
    let idealLow: Double
    let idealHigh: Double

    var idealMidpoint: Double { (idealLow + idealHigh) / 2.0 }
    var isInRange: Bool { measured >= idealLow && measured <= idealHigh }
    var deviation: Double { min(abs(measured - idealLow), abs(measured - idealHigh)) }
}

enum AngleParser {
    /// Parse strings like "Elbow: 102° (ideal: 155-175°)" or "Knee: 142° (ideal: 130-155°)"
    static func parse(_ angleString: String) -> CorrectionAngle? {
        let cleaned = angleString.replacingOccurrences(of: "°", with: "")

        // Extract the name (everything before the colon)
        guard let colonIdx = cleaned.firstIndex(of: ":") else { return nil }
        let name = String(cleaned[cleaned.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces).lowercased()

        let afterColon = String(cleaned[cleaned.index(after: colonIdx)...])

        // Extract measured value — first number after the colon
        guard let measured = extractFirstNumber(from: afterColon) else { return nil }

        // Extract ideal range — numbers after "ideal:"
        guard let idealRange = afterColon.range(of: "ideal", options: .caseInsensitive) else {
            return CorrectionAngle(name: name, measured: measured, idealLow: measured, idealHigh: measured)
        }

        let afterIdeal = String(afterColon[idealRange.upperBound...])
        let idealNumbers = extractAllNumbers(from: afterIdeal)

        guard idealNumbers.count >= 2 else { return nil }

        return CorrectionAngle(
            name: name,
            measured: measured,
            idealLow: idealNumbers[0],
            idealHigh: idealNumbers[1]
        )
    }

    /// Parse all key_angles from a PhaseDetail into structured data
    static func parseAll(_ keyAngles: [String]) -> [CorrectionAngle] {
        keyAngles.compactMap { parse($0) }
    }

    private static func extractFirstNumber(from string: String) -> Double? {
        let pattern = #"-?\d+\.?\d*"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let range = Range(match.range, in: string) else { return nil }
        return Double(string[range])
    }

    private static func extractAllNumbers(from string: String) -> [Double] {
        let pattern = #"-?\d+\.?\d*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: string) else { return nil }
            return Double(string[range])
        }
    }
}
