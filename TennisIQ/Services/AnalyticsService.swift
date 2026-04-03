import Foundation
import StoreKit
import os

@MainActor
final class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()

    private let logger = Logger(subsystem: "com.tennique.app", category: "Analytics")
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Event Tracking

    func trackEvent(_ event: AnalyticsEvent) {
        logger.info("[\(event.name)] \(event.parameters.description)")

        switch event {
        case .analysisCompleted:
            incrementCounter("total_analyses")
            checkRatingPromptEligibility()

        case .subscriptionViewed:
            incrementCounter("paywall_views")

        case .subscriptionPurchased(let tier):
            logger.info("Subscription purchased: \(tier)")

        case .onboardingCompleted:
            defaults.set(true, forKey: "onboarding_completed")

        default:
            break
        }
    }

    // MARK: - App Store Rating Prompt

    private func checkRatingPromptEligibility() {
        let totalAnalyses = defaults.integer(forKey: "total_analyses")
        let hasPrompted = defaults.bool(forKey: "has_prompted_rating")

        if totalAnalyses >= AppConstants.Feedback.minSessionsBeforeRatingPrompt && !hasPrompted {
            requestAppStoreRating()
            defaults.set(true, forKey: "has_prompted_rating")
        }
    }

    private func requestAppStoreRating() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        SKStoreReviewController.requestReview(in: windowScene)
    }

    // MARK: - Feedback Prompt Eligibility

    var shouldShowFeedbackPrompt: Bool {
        let totalAnalyses = defaults.integer(forKey: "total_analyses")
        let hasGivenFeedback = defaults.bool(forKey: "has_given_feedback")
        return totalAnalyses >= AppConstants.Feedback.minSessionsBeforePrompt && !hasGivenFeedback
    }

    func markFeedbackGiven() {
        defaults.set(true, forKey: "has_given_feedback")
    }

    // MARK: - Counters

    private func incrementCounter(_ key: String) {
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)
    }
}

// MARK: - Analytics Events

enum AnalyticsEvent {
    case appOpened
    case onboardingStarted
    case onboardingCompleted
    case recordingStarted
    case recordingCompleted(durationSeconds: Int)
    case analysisRequested
    case analysisCompleted(strokeCount: Int, overallGrade: String)
    case analysisFailed(error: String)
    case paywallTriggered(freeAnalysesUsed: Int)
    case subscriptionViewed
    case subscriptionPurchased(tier: String)
    case subscriptionRestored
    case progressViewed
    case sessionHistoryViewed
    case themeChanged(name: String)
    case feedbackSubmitted(rating: Int)
    case shareAnalysisTapped
    case feedbackPromptShown
    case feedbackPromptDismissed

    var name: String {
        switch self {
        case .appOpened: return "app_opened"
        case .onboardingStarted: return "onboarding_started"
        case .onboardingCompleted: return "onboarding_completed"
        case .recordingStarted: return "recording_started"
        case .recordingCompleted: return "recording_completed"
        case .analysisRequested: return "analysis_requested"
        case .analysisCompleted: return "analysis_completed"
        case .analysisFailed: return "analysis_failed"
        case .paywallTriggered: return "paywall_triggered"
        case .subscriptionViewed: return "subscription_viewed"
        case .subscriptionPurchased: return "subscription_purchased"
        case .subscriptionRestored: return "subscription_restored"
        case .progressViewed: return "progress_viewed"
        case .sessionHistoryViewed: return "session_history_viewed"
        case .themeChanged: return "theme_changed"
        case .feedbackSubmitted: return "feedback_submitted"
        case .shareAnalysisTapped: return "share_analysis_tapped"
        case .feedbackPromptShown: return "feedback_prompt_shown"
        case .feedbackPromptDismissed: return "feedback_prompt_dismissed"
        }
    }

    var parameters: [String: String] {
        switch self {
        case .recordingCompleted(let duration):
            return ["duration_seconds": "\(duration)"]
        case .analysisCompleted(let count, let grade):
            return ["stroke_count": "\(count)", "overall_grade": grade]
        case .analysisFailed(let error):
            return ["error": error]
        case .paywallTriggered(let used):
            return ["free_analyses_used": "\(used)"]
        case .subscriptionPurchased(let tier):
            return ["tier": tier]
        case .themeChanged(let name):
            return ["theme": name]
        case .feedbackSubmitted(let rating):
            return ["rating": "\(rating)"]
        default:
            return [:]
        }
    }
}
