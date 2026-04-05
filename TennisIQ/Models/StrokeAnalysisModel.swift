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
    var phaseBreakdownJSON: Data?
    var analysisCategoriesJSON: Data?
    var proComparisonJSON: Data?

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

    func correctionJoints(at timestamp: Double?) -> [JointData] {
        let fallback = jointSnapshot ?? []
        guard let timestamp, let session else { return fallback }
        return session.poseJoints(near: timestamp) ?? fallback
    }

    var verifiedSources: [String] {
        guard let data = verifiedSourcesJSON,
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    var phaseBreakdown: PhaseBreakdown? {
        guard let data = phaseBreakdownJSON else { return nil }
        return try? JSONDecoder().decode(PhaseBreakdown.self, from: data)
    }

    var analysisCategories: [AnalysisCategory]? {
        guard let data = analysisCategoriesJSON else { return nil }
        return try? JSONDecoder().decode([AnalysisCategory].self, from: data)
    }

    var proComparison: ProComparisonResult? {
        guard let data = proComparisonJSON else { return nil }
        return try? JSONDecoder().decode(ProComparisonResult.self, from: data)
    }
}

// MARK: - Stroke Type

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

// MARK: - Legacy Mechanics (backward compatible)

struct StrokeMechanics: Codable {
    let backswing: MechanicDetail?
    let contactPoint: MechanicDetail?
    let followThrough: MechanicDetail?
    let stance: MechanicDetail?
    let toss: MechanicDetail?

    enum CodingKeys: String, CodingKey {
        case backswing
        case contactPoint = "contact_point"
        case followThrough = "follow_through"
        case stance
        case toss
    }

    var averageScore: Double? {
        let all = [backswing, contactPoint, followThrough, stance, toss]
            .compactMap { $0?.score }
        guard !all.isEmpty else { return nil }
        return Double(all.reduce(0, +)) / Double(all.count)
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

// MARK: - Overlay Instructions (extended for swing path)

struct OverlayInstructions: Codable {
    let anglesToHighlight: [String]
    let trajectoryLine: Bool
    let comparisonGhost: Bool
    let swingPathPoints: [[Double]]?
    let swingPlaneAngle: Double?
    let pathAnnotations: [PathAnnotation]?

    enum CodingKeys: String, CodingKey {
        case anglesToHighlight = "angles_to_highlight"
        case trajectoryLine = "trajectory_line"
        case comparisonGhost = "comparison_ghost"
        case swingPathPoints = "swing_path_points"
        case swingPlaneAngle = "swing_plane_angle"
        case pathAnnotations = "path_annotations"
    }
}

struct PathAnnotation: Codable, Identifiable {
    var id: String { "\(label)_\(position[0])_\(position[1])" }

    let label: String
    let position: [Double]
    let status: ZoneStatus

    enum CodingKeys: String, CodingKey {
        case label, position, status
    }
}

// MARK: - 7-Phase Swing Breakdown

enum SwingPhase: String, Codable, CaseIterable {
    case readyPosition = "ready_position"
    case unitTurn = "unit_turn"
    case backswing = "backswing"
    case forwardSwing = "forward_swing"
    case contactPoint = "contact_point"
    case followThrough = "follow_through"
    case recovery = "recovery"

    var displayName: String {
        switch self {
        case .readyPosition: return "Split Step"
        case .unitTurn: return "Unit Turn"
        case .backswing: return "Backswing"
        case .forwardSwing: return "Forward Swing"
        case .contactPoint: return "Contact"
        case .followThrough: return "Follow-Through"
        case .recovery: return "Recovery"
        }
    }

    var icon: String {
        switch self {
        case .readyPosition: return "figure.stand"
        case .unitTurn: return "arrow.triangle.2.circlepath"
        case .backswing: return "arrow.uturn.backward"
        case .forwardSwing: return "arrow.forward"
        case .contactPoint: return "target"
        case .followThrough: return "arrow.up.forward"
        case .recovery: return "arrow.counterclockwise"
        }
    }
}

struct PhaseBreakdown: Codable {
    let readyPosition: PhaseDetail?
    let unitTurn: PhaseDetail?
    let backswing: PhaseDetail?
    let forwardSwing: PhaseDetail?
    let contactPoint: PhaseDetail?
    let followThrough: PhaseDetail?
    let recovery: PhaseDetail?

    enum CodingKeys: String, CodingKey {
        case readyPosition = "ready_position"
        case unitTurn = "unit_turn"
        case backswing
        case forwardSwing = "forward_swing"
        case contactPoint = "contact_point"
        case followThrough = "follow_through"
        case recovery
    }

    func detail(for phase: SwingPhase) -> PhaseDetail? {
        switch phase {
        case .readyPosition: return readyPosition
        case .unitTurn: return unitTurn
        case .backswing: return backswing
        case .forwardSwing: return forwardSwing
        case .contactPoint: return contactPoint
        case .followThrough: return followThrough
        case .recovery: return recovery
        }
    }

    var allPhases: [(SwingPhase, PhaseDetail?)] {
        SwingPhase.allCases.map { ($0, detail(for: $0)) }
    }
}

struct PhaseDetail: Codable {
    let score: Int
    let status: ZoneStatus
    let note: String
    let timestamp: Double
    let keyAngles: [String]
    let improveCue: String?
    let drill: String?

    enum CodingKeys: String, CodingKey {
        case score, status, note, timestamp
        case keyAngles = "key_angles"
        case improveCue = "improve_cue"
        case drill
    }
}

// MARK: - Zone Status

enum ZoneStatus: String, Codable {
    case inZone = "in_zone"
    case warning = "warning"
    case outOfZone = "out_of_zone"

    var displayLabel: String {
        switch self {
        case .inZone: return "In Zone"
        case .warning: return "Adjust"
        case .outOfZone: return "Out of Zone"
        }
    }
}

// MARK: - Analysis Categories (Report Card)

struct AnalysisCategory: Codable, Identifiable {
    var id: String { name }

    let name: String
    let description: String
    let status: ZoneStatus
    let subchecks: [SubCheck]
    let thumbnailPhase: String?

    enum CodingKeys: String, CodingKey {
        case name, description, status, subchecks
        case thumbnailPhase = "thumbnail_phase"
    }
}

struct SubCheck: Codable, Identifiable {
    var id: String { checkpoint }

    let checkpoint: String
    let result: String
    let status: ZoneStatus
}

// MARK: - Pro Comparison

struct ProComparisonResult: Codable {
    let proName: String
    let strokeType: String
    let alignmentScores: [AlignmentScore]
    let windowBadges: [WindowBadge]

    enum CodingKeys: String, CodingKey {
        case proName = "pro_name"
        case strokeType = "stroke_type"
        case alignmentScores = "alignment_scores"
        case windowBadges = "window_badges"
    }
}

struct AlignmentScore: Codable, Identifiable {
    var id: String { bodyGroup }

    let bodyGroup: String
    let percentage: Int
    let status: ZoneStatus

    enum CodingKeys: String, CodingKey {
        case bodyGroup = "body_group"
        case percentage, status
    }
}

struct WindowBadge: Codable, Identifiable {
    var id: String { label }

    let label: String
    let status: ZoneStatus
    let phase: String
}
