import Foundation

/// The structured response from the cloud LLM coaching engine
struct AnalysisResponse: Codable {
    let sessionGrade: String
    let strokesDetected: [StrokeResult]
    let tacticalNotes: [String]
    let topPriority: String
    let overallMechanicsScore: Double
    let sessionSummary: String

    enum CodingKeys: String, CodingKey {
        case sessionGrade = "session_grade"
        case strokesDetected = "strokes_detected"
        case tacticalNotes = "tactical_notes"
        case topPriority = "top_priority"
        case overallMechanicsScore = "overall_mechanics_score"
        case sessionSummary = "session_summary"
    }
}

struct StrokeResult: Codable, Identifiable {
    var id: String { "\(type.rawValue)_\(timestamp)" }

    let type: StrokeType
    let timestamp: Double
    let grade: String
    let mechanics: StrokeMechanics
    let overlayInstructions: OverlayInstructions
    let gradingRationale: String?
    let nextRepsPlan: String?
    let verifiedSources: [String]?
    let phaseBreakdown: PhaseBreakdown?
    let analysisCategories: [AnalysisCategory]?

    enum CodingKeys: String, CodingKey {
        case type
        case timestamp
        case grade
        case mechanics
        case overlayInstructions = "overlay_instructions"
        case gradingRationale = "grading_rationale"
        case nextRepsPlan = "next_reps_plan"
        case verifiedSources = "verified_sources"
        case phaseBreakdown = "phase_breakdown"
        case analysisCategories = "analysis_categories"
    }
}
