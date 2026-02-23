import Foundation
import SwiftData

@Model
final class ProgressSnapshotModel {
    @Attribute(.unique) var id: UUID
    var snapshotDate: Date
    var overallScore: Double
    var forehandScore: Double
    var backhandScore: Double
    var serveScore: Double
    var volleyScore: Double
    var sessionsCount: Int
    var trendingDirection: TrendDirection

    init(
        id: UUID = UUID(),
        snapshotDate: Date = Date(),
        overallScore: Double = 0,
        forehandScore: Double = 0,
        backhandScore: Double = 0,
        serveScore: Double = 0,
        volleyScore: Double = 0,
        sessionsCount: Int = 0,
        trendingDirection: TrendDirection = .stable
    ) {
        self.id = id
        self.snapshotDate = snapshotDate
        self.overallScore = overallScore
        self.forehandScore = forehandScore
        self.backhandScore = backhandScore
        self.serveScore = serveScore
        self.volleyScore = volleyScore
        self.sessionsCount = sessionsCount
        self.trendingDirection = trendingDirection
    }

    func score(for strokeType: StrokeType) -> Double {
        switch strokeType {
        case .forehand: return forehandScore
        case .backhand: return backhandScore
        case .serve: return serveScore
        case .volley: return volleyScore
        case .unknown: return 0
        }
    }
}

enum TrendDirection: String, Codable {
    case improving
    case stable
    case declining

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }
}
