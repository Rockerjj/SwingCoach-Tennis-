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

    // MARK: - Curated Drill Search Library
    // Format: ([keywords], youtubeSearchQuery)

    private static let drillSearchMap: [([String], String)] = [
        // Unit turn / shoulder turn / coil
        (["unit turn", "shoulder turn", "coil", "takeback", "hip turn"],
         "tennis forehand unit turn drill"),

        // Shadow swing / shadow forehands
        (["shadow", "shadow forehand", "shadow swing", "air swing"],
         "tennis shadow swing forehand drill"),

        // Split step / footwork
        (["split step", "split-step", "footwork", "ready position"],
         "tennis split step footwork drill"),

        // Forehand contact point / arm extension
        (["contact point", "arm extension", "reach", "contact arm"],
         "tennis forehand contact point extension drill"),

        // Follow-through
        (["follow-through", "follow through", "finish high", "windshield wiper"],
         "tennis forehand follow through drill"),

        // Backhand
        (["backhand", "two-handed", "two handed", "backhand slice"],
         "tennis backhand technique drill"),

        // Serve / toss
        (["serve", "toss", "serving", "trophy position", "pronation"],
         "tennis serve toss pronation drill"),

        // Volley
        (["volley", "net play", "punch volley"],
         "tennis volley technique drill"),

        // Drop feed / self-feed
        (["self-drop", "self drop", "drop feed", "self feed"],
         "tennis self drop forehand drill"),

        // Approach / transition
        (["approach", "transition", "inside-out", "inside out"],
         "tennis approach shot transition drill"),

        // Consistency / rally
        (["consistency", "rally", "cross-court", "down the line"],
         "tennis rally consistency drill")
    ]
}
