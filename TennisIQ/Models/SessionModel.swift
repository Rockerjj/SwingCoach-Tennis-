import Foundation
import SwiftData

@Model
final class SessionModel {
    @Attribute(.unique) var id: UUID
    var recordedAt: Date
    var durationSeconds: Int
    var status: SessionStatus
    var overallGrade: String?
    var topPriority: String?
    var tacticalNotes: [String]
    var videoLocalURL: String?
    var thumbnailData: Data?
    var poseFramesJSON: Data?

    @Relationship(deleteRule: .cascade, inverse: \StrokeAnalysisModel.session)
    var strokeAnalyses: [StrokeAnalysisModel]

    var poseFrames: [FramePoseData] {
        guard let data = poseFramesJSON else { return [] }
        return (try? JSONDecoder().decode([FramePoseData].self, from: data)) ?? []
    }

    func nearestPoseFrame(to timestamp: Double) -> FramePoseData? {
        let frames = poseFrames
        guard !frames.isEmpty else { return nil }
        return frames.min { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) }
    }

    func poseJoints(near timestamp: Double) -> [JointData]? {
        nearestPoseFrame(to: timestamp)?.joints
    }

    init(
        id: UUID = UUID(),
        recordedAt: Date = Date(),
        durationSeconds: Int = 0,
        status: SessionStatus = .recording,
        videoLocalURL: String? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.durationSeconds = durationSeconds
        self.status = status
        self.videoLocalURL = videoLocalURL
        self.overallGrade = nil
        self.topPriority = nil
        self.tacticalNotes = []
        self.thumbnailData = nil
        self.poseFramesJSON = nil
        self.strokeAnalyses = []
    }
}

enum SessionStatus: String, Codable {
    case recording
    case processing
    case analyzing
    case ready
    case failed
}
