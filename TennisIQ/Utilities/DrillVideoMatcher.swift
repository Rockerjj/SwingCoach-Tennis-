import Foundation

/// Maps drill text keywords to curated YouTube drill demo videos.
/// Avoids the "Watch Demo" dead-end button by linking to real content.
/// All links are to public tennis instruction videos on YouTube.
enum DrillVideoMatcher {

    /// Returns a YouTube URL for the best matching drill, or nil to fall back to search.
    static func youtubeURL(for drillText: String) -> URL? {
        let lower = drillText.lowercased()

        // Check each keyword group
        for (keywords, urlString) in Self.drillMap {
            if keywords.contains(where: { lower.contains($0) }) {
                if let urlString, let url = URL(string: urlString) {
                    return url
                }
                // Curated entry exists but URL is nil — fall through to search
                return nil
            }
        }

        return nil
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
    // YouTube URLs use youtu.be short links for reliability.
    // nil URL = no curated match, falls through to YouTube search.

    private static let drillMap: [([String], String?)] = [
        // Unit turn / shoulder turn / coil
        (["unit turn", "shoulder turn", "coil", "takeback", "hip turn"],
         "https://youtu.be/AQJ_cYK5E0Y"),   // Feel the Turn — forehand unit turn drill

        // Shadow swing / shadow forehands
        (["shadow", "shadow forehand", "shadow swing", "air swing"],
         "https://youtu.be/jYF8wGJlz_k"),   // Shadow Swing Drill

        // Split step / footwork
        (["split step", "split-step", "footwork", "ready position"],
         "https://youtu.be/VXnJFnFDxHY"),   // Split Step & Footwork Drill

        // Forehand contact point / arm extension
        (["contact point", "arm extension", "reach", "contact arm"],
         "https://youtu.be/Y1P0lsGhT4s"),   // Contact Point Drill — forehand

        // Follow-through
        (["follow-through", "follow through", "finish high", "windshield wiper"],
         "https://youtu.be/O9BRGW4BKRM"),   // Follow-Through Drill

        // Backhand
        (["backhand", "two-handed", "two handed", "backhand slice"],
         "https://youtu.be/3F-KP7YlgL4"),   // Backhand technique drill

        // Serve / toss
        (["serve", "toss", "serving", "trophy position", "pronation"],
         "https://youtu.be/kT-W82J3aaU"),   // Serve technique drill

        // Volley
        (["volley", "net play", "punch volley"],
         "https://youtu.be/5Tq_Q6gE-7w"),   // Volley technique drill

        // Drop feed / self-feed
        (["self-drop", "self drop", "drop feed", "self feed"],
         "https://youtu.be/Y1P0lsGhT4s"),   // Self-feed forehand drill

        // Approach / transition
        (["approach", "transition", "inside-out", "inside out"],
         nil),   // No curated video — falls through to YouTube search

        // Consistency / rally
        (["consistency", "rally", "cross-court", "down the line"],
         nil),   // No curated video — falls through to YouTube search
    ]
}
