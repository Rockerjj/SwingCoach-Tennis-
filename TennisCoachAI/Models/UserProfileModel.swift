import Foundation
import SwiftData

@Model
final class UserProfileModel {
    @Attribute(.unique) var id: UUID
    var appleUserID: String?
    var displayName: String
    var skillLevel: SkillLevel
    var subscriptionTier: SubscriptionTier
    var freeAnalysesUsed: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        appleUserID: String? = nil,
        displayName: String = "",
        skillLevel: SkillLevel = .beginner,
        subscriptionTier: SubscriptionTier = .free,
        freeAnalysesUsed: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.appleUserID = appleUserID
        self.displayName = displayName
        self.skillLevel = skillLevel
        self.subscriptionTier = subscriptionTier
        self.freeAnalysesUsed = freeAnalysesUsed
        self.createdAt = createdAt
    }

    var canAnalyze: Bool {
        subscriptionTier != .free || freeAnalysesUsed < AppConstants.Analysis.freeSessionsAllowed
    }
}

enum SkillLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"

    var displayName: String {
        rawValue.capitalized
    }

    var description: String {
        switch self {
        case .beginner: return "Learning the basics, developing consistency"
        case .intermediate: return "Comfortable rallying, working on shot variety"
        case .advanced: return "Tournament player, refining technique and tactics"
        }
    }
}

enum SubscriptionTier: String, Codable {
    case free = "free"
    case monthly = "monthly"
    case annual = "annual"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .monthly: return "Pro Monthly"
        case .annual: return "Pro Annual"
        }
    }
}
