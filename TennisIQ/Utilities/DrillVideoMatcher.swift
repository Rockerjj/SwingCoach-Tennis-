import Foundation

/// Maps drill text keywords to curated YouTube drill demo videos.
/// Avoids the "Watch Demo" dead-end button by linking to real content.
/// All links are to public tennis instruction videos on YouTube.
enum DrillVideoMatcher {

    /// Returns a YouTube URL for the best matching drill, or nil to fall back to search.
    /// Converts youtu.be short links to full youtube.com/watch URLs for better iOS app linking.
    static func youtubeURL(for drillText: String) -> URL? {
        let lower = drillText.lowercased()

        // Check each keyword group
        for (keywords, urlString) in Self.drillMap {
            if keywords.contains(where: { lower.contains($0) }) {
                if let urlString {
                    return expandYouTubeURL(urlString)
                }
                // Curated entry exists but URL is nil — fall through to search
                return nil
            }
        }

        return nil
    }

    /// Convert youtu.be/VIDEO_ID to youtube.com/watch?v=VIDEO_ID
    /// Full URLs work better with iOS universal links and open in the YouTube app
    private static func expandYouTubeURL(_ urlString: String) -> URL? {
        if urlString.contains("youtu.be/"),
           let videoID = urlString.components(separatedBy: "youtu.be/").last {
            return URL(string: "https://www.youtube.com/watch?v=\(videoID)")
        }
        return URL(string: urlString)
    }

    /// Always-valid YouTube search URL for a drill description.
    /// Uses a simple, robust encoding approach that won't break on special characters.
    static func youtubeSearchURL(for drillText: String) -> URL {
        // Take the first sentence or first 60 chars as the search query
        let raw = drillText
            .components(separatedBy: CharacterSet.newlines)
            .first?
            .components(separatedBy: ".")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "drill"

        // Limit length and prepend "tennis" for relevance
        let query = "tennis " + String(raw.prefix(80))

        // Use URLComponents for bulletproof percent-encoding
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.youtube.com"
        components.path = "/results"
        components.queryItems = [URLQueryItem(name: "search_query", value: query)]

        // URLComponents handles all encoding; fall back to a hardcoded safe URL
        return components.url ?? URL(string: "https://www.youtube.com/results?search_query=tennis+drill")!
    }

    // MARK: - Curated Drill Library
    // Format: ([keywords], youtubeURL?)
    // All IDs verified as public YouTube videos from established tennis channels.
    // nil URL = falls through to YouTube search.

    private static let drillMap: [([String], String?)] = [
        // Unit turn / shoulder turn / coil — Modern Forehand 8 Steps (Feel Tennis)
        (["unit turn", "shoulder turn", "coil", "takeback", "hip turn"],
         "https://youtu.be/9KRYA9ZlYmM"),

        // Shadow swing / shadow forehands — Forehand 8 Steps (Online Tennis Instruction)
        (["shadow", "shadow forehand", "shadow swing", "air swing"],
         "https://youtu.be/yyQ-v4V3NU8"),

        // Split step / footwork — Essential Drills for Movement (Tennis On Demand)
        (["split step", "split-step", "footwork", "ready position"],
         "https://youtu.be/Z8CNYjf-Uyk"),

        // Forehand contact point / arm extension — Forehand 8 Steps (Online Tennis Instruction)
        (["contact point", "arm extension", "reach", "contact arm"],
         "https://youtu.be/yyQ-v4V3NU8"),

        // Follow-through — Modern Forehand Technique (Feel Tennis)
        (["follow-through", "follow through", "finish high", "windshield wiper"],
         "https://youtu.be/9KRYA9ZlYmM"),

        // Backhand — falls through to YouTube search for best results
        (["backhand", "two-handed", "two handed", "backhand slice"],
         nil),

        // Serve toss — Serve Toss Masterclass (Chris Lewit)
        (["serve", "toss", "serving", "trophy position", "pronation"],
         "https://youtu.be/l0-DCcZSbIY"),

        // Volley — falls through to YouTube search for best results
        (["volley", "net play", "punch volley"],
         nil),

        // Drop feed / self-feed — Forehand technique lesson
        (["self-drop", "self drop", "drop feed", "self feed"],
         "https://youtu.be/yyQ-v4V3NU8"),

        // Approach / transition
        (["approach", "transition", "inside-out", "inside out"],
         nil),

        // Consistency / rally
        (["consistency", "rally", "cross-court", "down the line"],
         nil),
    ]
}
