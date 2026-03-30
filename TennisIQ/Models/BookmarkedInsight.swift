import Foundation
import SwiftData

/// A saved coaching insight that the user wants to revisit.
/// Bookmarked from the coaching card in analysis results.
@Model
final class BookmarkedInsight {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var strokeType: StrokeType
    var grade: String
    var coachingText: String       // gradingRationale or note
    var keyAngles: [String]        // e.g. ["Elbow: 68° (ideal: 85-95°)"]
    var jointSnapshotJSON: Data?   // [JointData] for angle correction replay
    var sessionDate: Date          // when the original session was recorded
    var phaseName: String?         // optional: which phase this was about
    var userNote: String?          // optional: user's own note about this

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        strokeType: StrokeType,
        grade: String,
        coachingText: String,
        keyAngles: [String] = [],
        jointSnapshotJSON: Data? = nil,
        sessionDate: Date = Date(),
        phaseName: String? = nil,
        userNote: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.strokeType = strokeType
        self.grade = grade
        self.coachingText = coachingText
        self.keyAngles = keyAngles
        self.jointSnapshotJSON = jointSnapshotJSON
        self.sessionDate = sessionDate
        self.phaseName = phaseName
        self.userNote = userNote
    }

    var jointSnapshot: [JointData]? {
        guard let data = jointSnapshotJSON else { return nil }
        return try? JSONDecoder().decode([JointData].self, from: data)
    }
}
