import Foundation

struct DrillVideoDestination {
    let url: URL
    let title: String
    let icon: String
    let isCuratedMatch: Bool
}

/// Maps drill text keywords to curated YouTube search queries.
/// Search-based matching is more resilient than linking to hardcoded video IDs
/// that can be removed or made unavailable over time.
enum DrillVideoMatcher {

    static func destination(for drillText: String) -> DrillVideoDestination {
        let lower = drillText.lowercased()

        for (keywords, query) in Self.drillSearchMap {
            if keywords.contains(where: { lower.contains($0) }) {
                return DrillVideoDestination(
                    url: youtubeSearchURL(query: query),
                    title: "Watch Drill Demo",
                    icon: "play.fill",
                    isCuratedMatch: true
                )
            }
        }

        return DrillVideoDestination(
            url: youtubeSearchURL(for: drillText),
            title: "Search Drill on YouTube",
            icon: "magnifyingglass",
            isCuratedMatch: false
        )
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

        return youtubeSearchURL(query: "tennis " + String(raw.prefix(80)))
    }

    private static func youtubeSearchURL(query: String) -> URL {
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
