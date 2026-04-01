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
                return URL(string: urlString)
            }
        }

        return nil
    }

    // MARK: - Curated Drill Library
    // Format: ([keywords], youtubeURL)
    // YouTube URLs use youtu.be short links for reliability

    private static let drillMap: [([String], String)] = [
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
         "https://youtu.be/4t-mS-Y6Fw0"),   // Approach shot drill

        // Consistency / rally
        (["consistency", "rally", "cross-court", "down the line"],
         "https://youtu.be/8cHkIDkOoEo"),   // Consistency rally drill
    ]
}
