import Foundation

/// Groups strokes by type and computes aggregate stats for the results view.
struct StrokeTypeSummary: Identifiable {
    var id: String { strokeType.rawValue }

    let strokeType: StrokeType
    let strokes: [StrokeAnalysisModel]
    let averageScore: Double
    let worstStroke: StrokeAnalysisModel
    let bestStroke: StrokeAnalysisModel
    let heroCoachingCue: String
    let worstPhaseName: String?
    let topDrill: String?

    /// Average grade letter derived from averageScore
    var averageGrade: String {
        switch Int(averageScore.rounded()) {
        case 96...100: return "A+"
        case 93...95: return "A"
        case 90...92: return "A-"
        case 87...89: return "B+"
        case 84...86: return "B"
        case 81...83: return "B-"
        case 78...80: return "C+"
        case 75...77: return "C"
        case 72...74: return "C-"
        case 69...71: return "D+"
        case 66...68: return "D"
        case 63...65: return "D-"
        default: return "F"
        }
    }
}

enum StrokeAggregator {

    /// Group strokes by type and compute summaries.
    static func aggregate(_ strokes: [StrokeAnalysisModel]) -> [StrokeTypeSummary] {
        let grouped = Dictionary(grouping: strokes) { $0.strokeType }

        return grouped.compactMap { type, group -> StrokeTypeSummary? in
            guard !group.isEmpty else { return nil }

            let scores = group.map { numericScore(for: $0.grade) }
            let avgScore = scores.reduce(0, +) / Double(scores.count)

            let sorted = group.sorted { numericScore(for: $0.grade) < numericScore(for: $1.grade) }
            let worst = sorted.first!
            let best = sorted.last!

            // Find the worst common phase across all strokes of this type
            let worstPhase = findWorstCommonPhase(in: group)

            // Pick the single most impactful coaching cue:
            // prefer the worst stroke's grading rationale, then its worst phase improve cue
            let heroCue = pickHeroCoachingCue(worst: worst, worstPhase: worstPhase)

            // Pick the top drill from the worst stroke
            let drill = worst.nextRepsPlan
                ?? worst.phaseBreakdown.flatMap { breakdown in
                    worstPhase.flatMap { breakdown.detail(for: $0)?.drill }
                }

            return StrokeTypeSummary(
                strokeType: type,
                strokes: group.sorted { $0.timestamp < $1.timestamp },
                averageScore: avgScore,
                worstStroke: worst,
                bestStroke: best,
                heroCoachingCue: heroCue,
                worstPhaseName: worstPhase?.displayName,
                topDrill: drill
            )
        }
        .sorted { $0.averageScore < $1.averageScore } // worst type first
    }

    // MARK: - Private Helpers

    private static func numericScore(for grade: String) -> Double {
        switch grade.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "A+": return 96; case "A": return 93; case "A-": return 90
        case "B+": return 87; case "B": return 84; case "B-": return 81
        case "C+": return 78; case "C": return 75; case "C-": return 72
        case "D+": return 69; case "D": return 66; case "D-": return 63
        case "F": return 55
        default: return 72
        }
    }

    /// Find the phase that scores lowest across the most strokes in this group.
    private static func findWorstCommonPhase(in strokes: [StrokeAnalysisModel]) -> SwingPhase? {
        var phaseScores: [SwingPhase: [Int]] = [:]

        for stroke in strokes {
            guard let breakdown = stroke.phaseBreakdown else { continue }
            for (phase, detail) in breakdown.allPhases {
                guard let detail else { continue }
                phaseScores[phase, default: []].append(detail.score)
            }
        }

        // Pick the phase with the lowest average score
        return phaseScores
            .map { phase, scores in
                (phase, Double(scores.reduce(0, +)) / Double(scores.count))
            }
            .min { $0.1 < $1.1 }?
            .0
    }

    private static func pickHeroCoachingCue(worst: StrokeAnalysisModel, worstPhase: SwingPhase?) -> String {
        // 1. Try worst stroke's grading rationale (first sentence)
        if let rationale = worst.gradingRationale, !rationale.isEmpty {
            let first = rationale
                .components(separatedBy: ".")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? rationale
            if !first.isEmpty { return first }
        }

        // 2. Try the worst phase's improve cue
        if let phase = worstPhase,
           let cue = worst.phaseBreakdown?.detail(for: phase)?.improveCue,
           !cue.isEmpty {
            return cue
        }

        // 3. Try worst phase note
        if let phase = worstPhase,
           let note = worst.phaseBreakdown?.detail(for: phase)?.note,
           !note.isEmpty {
            return note
        }

        // 4. Fallback
        return "Focus on consistent form across all reps"
    }
}
