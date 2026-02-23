import Foundation
import SwiftData

@Model
final class StrokeAnalysisModel {
    @Attribute(.unique) var id: UUID
    var session: SessionModel?
    var strokeType: StrokeType
    var timestamp: Double
    var grade: String
    var mechanicsJSON: Data?
    var overlayInstructionsJSON: Data?
    var jointSnapshotJSON: Data?
    var gradingRationale: String?
    var nextRepsPlan: String?
    var verifiedSourcesJSON: Data?

    init(
        id: UUID = UUID(),
        strokeType: StrokeType,
        timestamp: Double,
        grade: String
    ) {
        self.id = id
        self.strokeType = strokeType
        self.timestamp = timestamp
        self.grade = grade
    }

    var mechanics: StrokeMechanics? {
        guard let data = mechanicsJSON else { return nil }
        return try? JSONDecoder().decode(StrokeMechanics.self, from: data)
    }

    var overlayInstructions: OverlayInstructions? {
        guard let data = overlayInstructionsJSON else { return nil }
        return try? JSONDecoder().decode(OverlayInstructions.self, from: data)
    }

    var jointSnapshot: [JointData]? {
        guard let data = jointSnapshotJSON else { return nil }
        return try? JSONDecoder().decode([JointData].self, from: data)
    }

    var verifiedSources: [String] {
        guard let data = verifiedSourcesJSON,
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }
}

enum StrokeType: String, Codable, CaseIterable {
    case forehand = "forehand"
    case backhand = "backhand"
    case serve = "serve"
    case volley = "volley"
    case unknown = "unknown"

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .forehand: return "arrow.right"
        case .backhand: return "arrow.left"
        case .serve: return "arrow.up"
        case .volley: return "bolt.fill"
        case .unknown: return "questionmark"
        }
    }
}

struct StrokeMechanics: Codable {
    let backswing: MechanicDetail?
    let contactPoint: MechanicDetail?
    let followThrough: MechanicDetail?
    let stance: MechanicDetail?
    let toss: MechanicDetail? // serve-specific

    enum CodingKeys: String, CodingKey {
        case backswing
        case contactPoint = "contact_point"
        case followThrough = "follow_through"
        case stance
        case toss
    }
}

struct MechanicDetail: Codable {
    let score: Int
    let note: String
    let whyScore: String?
    let improveCue: String?
    let drill: String?
    let sources: [String]?

    enum CodingKeys: String, CodingKey {
        case score
        case note
        case whyScore = "why_score"
        case improveCue = "improve_cue"
        case drill
        case sources
    }
}

struct OverlayInstructions: Codable {
    let anglesToHighlight: [String]
    let trajectoryLine: Bool
    let comparisonGhost: Bool

    enum CodingKeys: String, CodingKey {
        case anglesToHighlight = "angles_to_highlight"
        case trajectoryLine = "trajectory_line"
        case comparisonGhost = "comparison_ghost"
    }
}
