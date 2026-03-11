# TENNIQUE CODEBASE — FULL SOURCE DUMP
Generated: Tue Mar 10 19:39:44 EDT 2026

---

## FILE: TennisIQ/App/MainTabView.swift
```swift
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .record

    enum Tab: String, CaseIterable {
        case record = "Record"
        case sessions = "Sessions"
        case progress = "Progress"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .record: return "video.fill"
            case .sessions: return "list.bullet.rectangle.fill"
            case .progress: return "chart.line.uptrend.xyaxis"
            case .profile: return "person.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            RecordView(switchToSessions: { selectedTab = .sessions })
                .tag(Tab.record)
                .tabItem {
                    Label(Tab.record.rawValue, systemImage: Tab.record.icon)
                }

            SessionsListView()
                .tag(Tab.sessions)
                .tabItem {
                    Label(Tab.sessions.rawValue, systemImage: Tab.sessions.icon)
                }

            ProgressDashboardView()
                .tag(Tab.progress)
                .tabItem {
                    Label(Tab.progress.rawValue, systemImage: Tab.progress.icon)
                }

            ProfileView()
                .tag(Tab.profile)
                .tabItem {
                    Label(Tab.profile.rawValue, systemImage: Tab.profile.icon)
                }
        }
        .tint(DesignSystem.current.accent)
    }
}
```


## FILE: TennisIQ/App/RootView.swift
```swift
import SwiftUI

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            } else if !authService.isAuthenticated {
                SignInView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
    }
}
```


## FILE: TennisIQ/App/TennisIQApp.swift
```swift
import SwiftUI
import SwiftData

@main
struct TennisIQApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var subscriptionService = SubscriptionService()
    private let analytics = AnalyticsService.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SessionModel.self,
            StrokeAnalysisModel.self,
            ProgressSnapshotModel.self,
            UserProfileModel.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .environmentObject(subscriptionService)
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(.light)
                .onAppear {
                    analytics.trackEvent(.appOpened)
                }
        }
    }
}
```


## FILE: TennisIQ/Design/CourtVisionTheme.swift
```swift
import SwiftUI

/// Scheme 1: "Court Vision" — Dark Athletic Precision
/// Dark charcoal base + electric lime accent. Pro video tool meets sports analytics.
struct CourtVisionTheme: AppTheme {
    let name = "Court Vision"

    // Backgrounds
    let background = Color(hex: "0A0A0F")
    let surfacePrimary = Color(hex: "141419")
    let surfaceSecondary = Color(hex: "1C1C24")
    let surfaceElevated = Color(hex: "24242E")

    // Accents — tennis ball electric lime
    let accent = Color(hex: "C8FF00")
    let accentSecondary = Color(hex: "3B82F6")
    let accentMuted = Color(hex: "C8FF00").opacity(0.15)

    // Text
    let textPrimary = Color(hex: "F0F0F5")
    let textSecondary = Color(hex: "9898A8")
    let textTertiary = Color(hex: "5C5C6E")
    let textOnAccent = Color(hex: "0A0A0F")

    // Semantic
    let success = Color(hex: "34D399")
    let warning = Color(hex: "FBBF24")
    let error = Color(hex: "E85D3A")

    // Overlay — neon lime skeleton
    let skeletonStroke = Color(hex: "C8FF00")
    let skeletonCorrect = Color(hex: "34D399")
    let skeletonWarning = Color(hex: "E85D3A")
    let angleAnnotation = Color(hex: "C8FF00").opacity(0.9)
    let trajectoryLine = Color(hex: "3B82F6")

    // Typography
    let displayFont = "DMSans-Bold"
    let bodyFont = "IBMPlexSans"
    let monoFont = "JetBrainsMono-Medium"
}
```


## FILE: TennisIQ/Design/DesignSystem.swift
```swift
import SwiftUI

// MARK: - Theme Protocol

protocol AppTheme {
    var name: String { get }

    // Backgrounds
    var background: Color { get }
    var surfacePrimary: Color { get }
    var surfaceSecondary: Color { get }
    var surfaceElevated: Color { get }

    // Accents
    var accent: Color { get }
    var accentSecondary: Color { get }
    var accentMuted: Color { get }

    // Text
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    var textOnAccent: Color { get }

    // Semantic
    var success: Color { get }
    var warning: Color { get }
    var error: Color { get }

    // Overlay-specific
    var skeletonStroke: Color { get }
    var skeletonCorrect: Color { get }
    var skeletonWarning: Color { get }
    var angleAnnotation: Color { get }
    var trajectoryLine: Color { get }

    // Typography
    var displayFont: String { get }
    var bodyFont: String { get }
    var monoFont: String { get }
}

// MARK: - Design System Singleton

final class DesignSystem: ObservableObject {
    static let shared = DesignSystem()

    @Published var currentTheme: AppTheme = GrandSlamTheme()

    static var current: AppTheme {
        shared.currentTheme
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
}

// MARK: - Typography Helpers

struct AppFont {
    static func display(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom(DesignSystem.current.displayFont, size: size).weight(weight)
    }

    static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(DesignSystem.current.bodyFont, size: size).weight(weight)
    }

    static func mono(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .custom(DesignSystem.current.monoFont, size: size).weight(weight)
    }
}

// MARK: - Spacing Scale

enum Spacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius Scale

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 999
}
```


## FILE: TennisIQ/Design/GrandSlamTheme.swift
```swift
import SwiftUI

/// Scheme 2: "Grand Slam" — Refined with Roland Garros clay tones
/// Warm off-white + Wimbledon green + Championship gold + French Open clay
/// Tasteful, muted, satisfying, calming.
struct GrandSlamTheme: AppTheme {
    let name = "Grand Slam"

    // Backgrounds — warm cream
    let background = Color(hex: "FAF8F5")
    let surfacePrimary = Color(hex: "FFFFFF")
    let surfaceSecondary = Color(hex: "F3EFE8")
    let surfaceElevated = Color(hex: "FFFFFF")

    // Accents — Wimbledon green (authority) + Championship gold (warmth) + Roland Garros clay (energy)
    let accent = Color(hex: "2D5F45")
    let accentSecondary = Color(hex: "BFA14A")
    let accentMuted = Color(hex: "2D5F45").opacity(0.06)

    // Text
    let textPrimary = Color(hex: "1F2421")
    let textSecondary = Color(hex: "5A6058")
    let textTertiary = Color(hex: "8E9189")
    let textOnAccent = Color(hex: "FAF8F5")

    // Semantic — calming, muted score palette
    let success = Color(hex: "5E8E6B")     // Sage green — mastery
    let warning = Color(hex: "BFA14A")     // Warm gold — developing
    let error = Color(hex: "C4876B")       // Clay salmon — needs attention

    // Extended score palette (for score bars in views)
    static let scoreExcellent = Color(hex: "5E8E6B")   // 8-10
    static let scoreGood = Color(hex: "7EA882")         // 7
    static let scoreFair = Color(hex: "BFA14A")         // 5-6
    static let scoreNeedsWork = Color(hex: "C4876B")    // 3-4
    static let scorePoor = Color(hex: "B07272")         // 1-2

    // Roland Garros clay as a named color
    static let clay = Color(hex: "C4876B")
    static let goldMuted = Color(hex: "BFA14A").opacity(0.08)
    static let clayMuted = Color(hex: "C4876B").opacity(0.07)

    // Overlay — clean white skeleton, sage correct, clay warning
    let skeletonStroke = Color(hex: "FFFFFF").opacity(0.92)
    let skeletonCorrect = Color(hex: "5E8E6B")
    let skeletonWarning = Color(hex: "C4876B")
    let angleAnnotation = Color(hex: "BFA14A")
    let trajectoryLine = Color(hex: "2D5F45")

    // Typography — editorial luxury
    let displayFont = "Fraunces-Bold"
    let bodyFont = "Outfit-Regular"
    let monoFont = "JetBrainsMono-Medium"
}
```


## FILE: TennisIQ/Design/RallyTheme.swift
```swift
import SwiftUI

/// Scheme 3: "Rally" — Bold Sport-Tech
/// Navy base + hot coral for problems + cyan for correct form. Energetic data-driven aesthetic.
struct RallyTheme: AppTheme {
    let name = "Rally"

    // Backgrounds
    let background = Color(hex: "0C1222")
    let surfacePrimary = Color(hex: "111827")
    let surfaceSecondary = Color(hex: "1A2236")
    let surfaceElevated = Color(hex: "222D45")

    // Accents — coral energy + cyan data
    let accent = Color(hex: "FF5C5C")
    let accentSecondary = Color(hex: "00D4FF")
    let accentMuted = Color(hex: "FF5C5C").opacity(0.12)

    // Text
    let textPrimary = Color(hex: "F0F4FF")
    let textSecondary = Color(hex: "8892A8")
    let textTertiary = Color(hex: "4A5568")
    let textOnAccent = Color(hex: "FFFFFF")

    // Semantic
    let success = Color(hex: "00D4FF")
    let warning = Color(hex: "FFB547")
    let error = Color(hex: "FF5C5C")

    // Overlay — dual-tone skeleton (coral = problem, cyan = correct)
    let skeletonStroke = Color(hex: "00D4FF")
    let skeletonCorrect = Color(hex: "00D4FF")
    let skeletonWarning = Color(hex: "FF5C5C")
    let angleAnnotation = Color(hex: "FFB547")
    let trajectoryLine = Color(hex: "00D4FF").opacity(0.7)

    // Typography
    let displayFont = "SpaceMono-Bold"
    let bodyFont = "Satoshi-Regular"
    let monoFont = "SpaceMono-Regular"
}
```


## FILE: TennisIQ/Models/AnalysisResponse.swift
```swift
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
```


## FILE: TennisIQ/Models/PoseData.swift
```swift
import Foundation
import Vision

/// Raw pose data extracted from a single video frame
struct FramePoseData: Codable {
    let frameIndex: Int
    let timestamp: Double
    let joints: [JointData]
    let confidence: Float

    enum CodingKeys: String, CodingKey {
        case frameIndex = "frame_index"
        case timestamp
        case joints
        case confidence
    }
}

struct JointData: Codable {
    let name: String
    let x: Double
    let y: Double
    let confidence: Float
}

/// Aggregated pose data for an entire session, ready to send to API
struct SessionPosePayload: Codable {
    let sessionID: String
    let durationSeconds: Int
    let fps: Int
    let frames: [FramePoseData]
    let keyFrameTimestamps: [Double]
    let skillLevel: String
    let handedness: String
    let detectedStrokes: [DetectedStroke]

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case durationSeconds = "duration_seconds"
        case fps
        case frames
        case keyFrameTimestamps = "key_frame_timestamps"
        case skillLevel = "skill_level"
        case handedness
        case detectedStrokes = "detected_strokes"
    }
}

/// Maps Vision framework joint names to our canonical names
enum JointMapping {
    static func canonicalName(for joint: VNHumanBodyPoseObservation.JointName) -> String {
        switch joint {
        case .nose: return "nose"
        case .leftEye: return "left_eye"
        case .rightEye: return "right_eye"
        case .leftEar: return "left_ear"
        case .rightEar: return "right_ear"
        case .leftShoulder: return "left_shoulder"
        case .rightShoulder: return "right_shoulder"
        case .leftElbow: return "left_elbow"
        case .rightElbow: return "right_elbow"
        case .leftWrist: return "left_wrist"
        case .rightWrist: return "right_wrist"
        case .leftHip: return "left_hip"
        case .rightHip: return "right_hip"
        case .leftKnee: return "left_knee"
        case .rightKnee: return "right_knee"
        case .leftAnkle: return "left_ankle"
        case .rightAnkle: return "right_ankle"
        default: return "unknown"
        }
    }

    static let allJoints: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .leftEye, .rightEye, .leftEar, .rightEar,
        .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
        .leftWrist, .rightWrist, .leftHip, .rightHip,
        .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
    ]
}
```


## FILE: TennisIQ/Models/ProgressSnapshotModel.swift
```swift
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
```


## FILE: TennisIQ/Models/SessionModel.swift
```swift
import Foundation
import SwiftData

@Model
final class SessionModel {
    @Attribute(.unique) var id: UUID
    var recordedAt: Date
    var durationSeconds: Int
    var status: SessionStatus
    var overallGrade: String?
    var topPriority: String?
    var tacticalNotes: [String]
    var videoLocalURL: String?
    var thumbnailData: Data?
    var poseFramesJSON: Data?

    @Relationship(deleteRule: .cascade, inverse: \StrokeAnalysisModel.session)
    var strokeAnalyses: [StrokeAnalysisModel]

    var poseFrames: [FramePoseData] {
        guard let data = poseFramesJSON else { return [] }
        return (try? JSONDecoder().decode([FramePoseData].self, from: data)) ?? []
    }

    init(
        id: UUID = UUID(),
        recordedAt: Date = Date(),
        durationSeconds: Int = 0,
        status: SessionStatus = .recording,
        videoLocalURL: String? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.durationSeconds = durationSeconds
        self.status = status
        self.videoLocalURL = videoLocalURL
        self.overallGrade = nil
        self.topPriority = nil
        self.tacticalNotes = []
        self.thumbnailData = nil
        self.poseFramesJSON = nil
        self.strokeAnalyses = []
    }
}

enum SessionStatus: String, Codable {
    case recording
    case processing
    case analyzing
    case ready
    case failed
}
```


## FILE: TennisIQ/Models/StrokeAnalysisModel.swift
```swift
import Foundation
import SwiftData

@Model
final class StrokeAnalysisModel {
    @Attribute(.unique) var id: UUID
    var session: SessionModel?
    var strokeType: StrokeType
    var timestamp: Double
    var grade: String
    var mechanicsJSON: Data?
    var overlayInstructionsJSON: Data?
    var jointSnapshotJSON: Data?
    var gradingRationale: String?
    var nextRepsPlan: String?
    var verifiedSourcesJSON: Data?
    var phaseBreakdownJSON: Data?
    var analysisCategoriesJSON: Data?
    var proComparisonJSON: Data?

    init(
        id: UUID = UUID(),
        strokeType: StrokeType,
        timestamp: Double,
        grade: String
    ) {
        self.id = id
        self.strokeType = strokeType
        self.timestamp = timestamp
        self.grade = grade
    }

    var mechanics: StrokeMechanics? {
        guard let data = mechanicsJSON else { return nil }
        return try? JSONDecoder().decode(StrokeMechanics.self, from: data)
    }

    var overlayInstructions: OverlayInstructions? {
        guard let data = overlayInstructionsJSON else { return nil }
        return try? JSONDecoder().decode(OverlayInstructions.self, from: data)
    }

    var jointSnapshot: [JointData]? {
        guard let data = jointSnapshotJSON else { return nil }
        return try? JSONDecoder().decode([JointData].self, from: data)
    }

    var verifiedSources: [String] {
        guard let data = verifiedSourcesJSON,
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    var phaseBreakdown: PhaseBreakdown? {
        guard let data = phaseBreakdownJSON else { return nil }
        return try? JSONDecoder().decode(PhaseBreakdown.self, from: data)
    }

    var analysisCategories: [AnalysisCategory]? {
        guard let data = analysisCategoriesJSON else { return nil }
        return try? JSONDecoder().decode([AnalysisCategory].self, from: data)
    }

    var proComparison: ProComparisonResult? {
        guard let data = proComparisonJSON else { return nil }
        return try? JSONDecoder().decode(ProComparisonResult.self, from: data)
    }
}

// MARK: - Stroke Type

enum StrokeType: String, Codable, CaseIterable {
    case forehand = "forehand"
    case backhand = "backhand"
    case serve = "serve"
    case volley = "volley"
    case unknown = "unknown"

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .forehand: return "arrow.right"
        case .backhand: return "arrow.left"
        case .serve: return "arrow.up"
        case .volley: return "bolt.fill"
        case .unknown: return "questionmark"
        }
    }
}

// MARK: - Legacy Mechanics (backward compatible)

struct StrokeMechanics: Codable {
    let backswing: MechanicDetail?
    let contactPoint: MechanicDetail?
    let followThrough: MechanicDetail?
    let stance: MechanicDetail?
    let toss: MechanicDetail?

    enum CodingKeys: String, CodingKey {
        case backswing
        case contactPoint = "contact_point"
        case followThrough = "follow_through"
        case stance
        case toss
    }
}

struct MechanicDetail: Codable {
    let score: Int
    let note: String
    let whyScore: String?
    let improveCue: String?
    let drill: String?
    let sources: [String]?

    enum CodingKeys: String, CodingKey {
        case score
        case note
        case whyScore = "why_score"
        case improveCue = "improve_cue"
        case drill
        case sources
    }
}

// MARK: - Overlay Instructions (extended for swing path)

struct OverlayInstructions: Codable {
    let anglesToHighlight: [String]
    let trajectoryLine: Bool
    let comparisonGhost: Bool
    let swingPathPoints: [[Double]]?
    let swingPlaneAngle: Double?
    let pathAnnotations: [PathAnnotation]?

    enum CodingKeys: String, CodingKey {
        case anglesToHighlight = "angles_to_highlight"
        case trajectoryLine = "trajectory_line"
        case comparisonGhost = "comparison_ghost"
        case swingPathPoints = "swing_path_points"
        case swingPlaneAngle = "swing_plane_angle"
        case pathAnnotations = "path_annotations"
    }
}

struct PathAnnotation: Codable, Identifiable {
    var id: String { "\(label)_\(position[0])_\(position[1])" }

    let label: String
    let position: [Double]
    let status: ZoneStatus

    enum CodingKeys: String, CodingKey {
        case label, position, status
    }
}

// MARK: - 7-Phase Swing Breakdown

enum SwingPhase: String, Codable, CaseIterable {
    case readyPosition = "ready_position"
    case unitTurn = "unit_turn"
    case backswing = "backswing"
    case forwardSwing = "forward_swing"
    case contactPoint = "contact_point"
    case followThrough = "follow_through"
    case recovery = "recovery"

    var displayName: String {
        switch self {
        case .readyPosition: return "Split Step"
        case .unitTurn: return "Unit Turn"
        case .backswing: return "Backswing"
        case .forwardSwing: return "Forward Swing"
        case .contactPoint: return "Contact"
        case .followThrough: return "Follow-Through"
        case .recovery: return "Recovery"
        }
    }

    var icon: String {
        switch self {
        case .readyPosition: return "figure.stand"
        case .unitTurn: return "arrow.triangle.2.circlepath"
        case .backswing: return "arrow.uturn.backward"
        case .forwardSwing: return "arrow.forward"
        case .contactPoint: return "target"
        case .followThrough: return "arrow.up.forward"
        case .recovery: return "arrow.counterclockwise"
        }
    }
}

struct PhaseBreakdown: Codable {
    let readyPosition: PhaseDetail?
    let unitTurn: PhaseDetail?
    let backswing: PhaseDetail?
    let forwardSwing: PhaseDetail?
    let contactPoint: PhaseDetail?
    let followThrough: PhaseDetail?
    let recovery: PhaseDetail?

    enum CodingKeys: String, CodingKey {
        case readyPosition = "ready_position"
        case unitTurn = "unit_turn"
        case backswing
        case forwardSwing = "forward_swing"
        case contactPoint = "contact_point"
        case followThrough = "follow_through"
        case recovery
    }

    func detail(for phase: SwingPhase) -> PhaseDetail? {
        switch phase {
        case .readyPosition: return readyPosition
        case .unitTurn: return unitTurn
        case .backswing: return backswing
        case .forwardSwing: return forwardSwing
        case .contactPoint: return contactPoint
        case .followThrough: return followThrough
        case .recovery: return recovery
        }
    }

    var allPhases: [(SwingPhase, PhaseDetail?)] {
        SwingPhase.allCases.map { ($0, detail(for: $0)) }
    }
}

struct PhaseDetail: Codable {
    let score: Int
    let status: ZoneStatus
    let note: String
    let timestamp: Double
    let keyAngles: [String]
    let improveCue: String?
    let drill: String?

    enum CodingKeys: String, CodingKey {
        case score, status, note, timestamp
        case keyAngles = "key_angles"
        case improveCue = "improve_cue"
        case drill
    }
}

// MARK: - Zone Status

enum ZoneStatus: String, Codable {
    case inZone = "in_zone"
    case warning = "warning"
    case outOfZone = "out_of_zone"

    var displayLabel: String {
        switch self {
        case .inZone: return "In Zone"
        case .warning: return "Adjust"
        case .outOfZone: return "Out of Zone"
        }
    }
}

// MARK: - Analysis Categories (Report Card)

struct AnalysisCategory: Codable, Identifiable {
    var id: String { name }

    let name: String
    let description: String
    let status: ZoneStatus
    let subchecks: [SubCheck]
    let thumbnailPhase: String?

    enum CodingKeys: String, CodingKey {
        case name, description, status, subchecks
        case thumbnailPhase = "thumbnail_phase"
    }
}

struct SubCheck: Codable, Identifiable {
    var id: String { checkpoint }

    let checkpoint: String
    let result: String
    let status: ZoneStatus
}

// MARK: - Pro Comparison

struct ProComparisonResult: Codable {
    let proName: String
    let strokeType: String
    let alignmentScores: [AlignmentScore]
    let windowBadges: [WindowBadge]

    enum CodingKeys: String, CodingKey {
        case proName = "pro_name"
        case strokeType = "stroke_type"
        case alignmentScores = "alignment_scores"
        case windowBadges = "window_badges"
    }
}

struct AlignmentScore: Codable, Identifiable {
    var id: String { bodyGroup }

    let bodyGroup: String
    let percentage: Int
    let status: ZoneStatus

    enum CodingKeys: String, CodingKey {
        case bodyGroup = "body_group"
        case percentage, status
    }
}

struct WindowBadge: Codable, Identifiable {
    var id: String { label }

    let label: String
    let status: ZoneStatus
    let phase: String
}
```


## FILE: TennisIQ/Models/UserProfileModel.swift
```swift
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

enum Handedness: String, Codable, CaseIterable {
    case right = "right"
    case left = "left"

    var displayName: String {
        rawValue.capitalized
    }

    var dominantWrist: String {
        self == .right ? "right_wrist" : "left_wrist"
    }

    var dominantElbow: String {
        self == .right ? "right_elbow" : "left_elbow"
    }

    var dominantShoulder: String {
        self == .right ? "right_shoulder" : "left_shoulder"
    }

    static var current: Handedness {
        let stored = UserDefaults.standard.string(forKey: "handedness") ?? "right"
        return Handedness(rawValue: stored) ?? .right
    }

    static func save(_ hand: Handedness) {
        UserDefaults.standard.set(hand.rawValue, forKey: "handedness")
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
```


## FILE: TennisIQ/Services/AnalysisAPIService.swift
```swift
import Foundation
import UIKit

/// Handles communication with the cloud analysis API
final class AnalysisAPIService {
    private let session: URLSession
    private let baseURL: String

    init(session: URLSession = .shared) {
        self.session = session
        #if DEBUG
        self.baseURL = AppConstants.API.debugBaseURL
        #else
        self.baseURL = AppConstants.API.baseURL
        #endif
    }

    enum APIError: LocalizedError {
        case invalidURL
        case uploadFailed(String)
        case analysisFailed(String)
        case decodingFailed
        case unauthorized

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL."
            case .uploadFailed(let msg): return "Upload failed: \(msg)"
            case .analysisFailed(let msg): return "Analysis failed: \(msg)"
            case .decodingFailed: return "Failed to decode analysis response."
            case .unauthorized: return "Please sign in to continue."
            }
        }
    }

    // MARK: - Submit Session for Analysis

    func analyzeSession(
        posePayload: SessionPosePayload,
        keyFrameImages: [(timestamp: Double, image: UIImage)],
        authToken: String
    ) async throws -> AnalysisResponse {
        guard let url = URL(string: "\(baseURL)/sessions/analyze") else {
            throw APIError.invalidURL
        }

        // Build multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        // Long sessions can take a while between upload + LLM analysis.
        request.timeoutInterval = 300

        var body = Data()

        // Pose data JSON
        let poseJSON = try JSONEncoder().encode(posePayload)
        body.appendMultipart(boundary: boundary, name: "pose_data", filename: "pose.json", mimeType: "application/json", data: poseJSON)

        // Key frame images
        for (index, keyFrame) in keyFrameImages.enumerated() {
            guard let jpegData = keyFrame.image.jpegData(compressionQuality: 0.7) else { continue }
            body.appendMultipart(
                boundary: boundary,
                name: "key_frame_\(index)",
                filename: "frame_\(index)_\(String(format: "%.2f", keyFrame.timestamp)).jpg",
                mimeType: "image/jpeg",
                data: jpegData
            )
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.analysisFailed("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try JSONDecoder().decode(AnalysisResponse.self, from: data)
            } catch {
                throw APIError.decodingFailed
            }
        case 401:
            throw APIError.unauthorized
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.analysisFailed(message)
        }
    }

    // MARK: - Fetch Session History

    func fetchSessions(authToken: String) async throws -> [SessionSummary] {
        guard let url = URL(string: "\(baseURL)/sessions") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode([SessionSummary].self, from: data)
    }

    // MARK: - Fetch Progress

    func fetchProgress(authToken: String) async throws -> ProgressData {
        guard let url = URL(string: "\(baseURL)/progress") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(ProgressData.self, from: data)
    }
}

// MARK: - API Response Types

struct SessionSummary: Codable, Identifiable {
    let id: String
    let recordedAt: String
    let durationSeconds: Int
    let overallGrade: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case recordedAt = "recorded_at"
        case durationSeconds = "duration_seconds"
        case overallGrade = "overall_grade"
        case status
    }
}

struct ProgressData: Codable {
    let overallScore: Double
    let forehandScore: Double
    let backhandScore: Double
    let serveScore: Double
    let volleyScore: Double
    let trend: String
    let weeklyFocus: String
    let sessionsThisWeek: Int
    let sessionsThisMonth: Int
    let history: [ProgressPoint]

    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score"
        case forehandScore = "forehand_score"
        case backhandScore = "backhand_score"
        case serveScore = "serve_score"
        case volleyScore = "volley_score"
        case trend
        case weeklyFocus = "weekly_focus"
        case sessionsThisWeek = "sessions_this_week"
        case sessionsThisMonth = "sessions_this_month"
        case history
    }
}

struct ProgressPoint: Codable, Identifiable {
    var id: String { date }
    let date: String
    let score: Double
}

// MARK: - Multipart Helper

extension Data {
    mutating func appendMultipart(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
```


## FILE: TennisIQ/Services/AnalyticsService.swift
```swift
import Foundation
import StoreKit
import os

@MainActor
final class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()

    private let logger = Logger(subsystem: "com.tennisiq.app", category: "Analytics")
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
```


## FILE: TennisIQ/Services/AuthService.swift
```swift
import Foundation
import AuthenticationServices
import Combine

@MainActor
final class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUserID: String?
    @Published var displayName: String?
    @Published var isLoading = false
    @Published var error: AuthError?

    private let keychain = KeychainHelper.shared

    enum AuthError: LocalizedError {
        case signInFailed(String)
        case tokenExpired
        case unknown

        var errorDescription: String? {
            switch self {
            case .signInFailed(let msg): return "Sign in failed: \(msg)"
            case .tokenExpired: return "Session expired. Please sign in again."
            case .unknown: return "An unknown error occurred."
            }
        }
    }

    init() {
        checkExistingSession()
    }

    private func checkExistingSession() {
        if let userID = keychain.read(key: "apple_user_id") {
            currentUserID = userID
            displayName = keychain.read(key: "display_name")
            isAuthenticated = true
        }
    }

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                error = .signInFailed("Invalid credential type")
                return
            }

            let userID = credential.user
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            keychain.save(key: "apple_user_id", value: userID)
            if !name.isEmpty {
                keychain.save(key: "display_name", value: name)
            }

            if let identityToken = credential.identityToken,
               let tokenString = String(data: identityToken, encoding: .utf8) {
                keychain.save(key: "apple_id_token", value: tokenString)
            }

            currentUserID = userID
            displayName = name.isEmpty ? nil : name
            isAuthenticated = true

        case .failure(let err):
            if (err as? ASAuthorizationError)?.code == .canceled { return }
            error = .signInFailed(err.localizedDescription)
        }
    }

    func continueAsGuest() {
        let guestID = UUID().uuidString
        keychain.save(key: "apple_user_id", value: guestID)
        keychain.save(key: "display_name", value: "Guest")
        currentUserID = guestID
        displayName = "Guest"
        isAuthenticated = true
    }

    func signOut() {
        keychain.delete(key: "apple_user_id")
        keychain.delete(key: "display_name")
        keychain.delete(key: "apple_id_token")
        currentUserID = nil
        displayName = nil
        isAuthenticated = false
    }
}

// MARK: - Keychain Helper

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```


## FILE: TennisIQ/Services/CameraService.swift
```swift
import AVFoundation
import AVFAudio
import UIKit
import Combine

final class CameraService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var error: CameraError?

    private var captureSession: AVCaptureSession?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var timer: Timer?
    private var currentVideoURL: URL?
    private var recordingStartTime: Date?

    private var completionHandler: ((Result<URL, CameraError>) -> Void)?

    enum CameraError: LocalizedError {
        case unauthorized
        case setupFailed(String)
        case recordingFailed(String)
        case deviceUnavailable

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "Camera access is required to record tennis sessions."
            case .setupFailed(let msg):
                return "Camera setup failed: \(msg)"
            case .recordingFailed(let msg):
                return "Recording failed: \(msg)"
            case .deviceUnavailable:
                return "No camera available on this device."
            }
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            await MainActor.run { self.error = .unauthorized }
            return false
        }
    }

    // MARK: - Session Setup

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }

    @MainActor
    func setupSession() async throws {
        guard await requestAuthorization() else {
            throw CameraError.unauthorized
        }

        configureAudioSession()

        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            throw CameraError.deviceUnavailable
        }

        // Configure for 60fps if available
        try configureFrameRate(device: videoDevice, desiredFPS: AppConstants.Camera.defaultFPS)

        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        guard session.canAddInput(videoInput) else {
            throw CameraError.setupFailed("Cannot add video input")
        }
        session.addInput(videoInput)

        // Audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        let output = AVCaptureMovieFileOutput()
        output.maxRecordedDuration = CMTime(
            seconds: AppConstants.Camera.maxRecordingDuration,
            preferredTimescale: 600
        )
        guard session.canAddOutput(output) else {
            throw CameraError.setupFailed("Cannot add movie output")
        }
        session.addOutput(output)

        self.captureSession = session
        self.movieOutput = output

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        self.previewLayer = layer

        Task.detached { [weak session] in
            session?.startRunning()
        }
    }

    private func configureFrameRate(device: AVCaptureDevice, desiredFPS: Int) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        let targetFPS = CMTime(value: 1, timescale: CMTimeScale(desiredFPS))
        for range in device.activeFormat.videoSupportedFrameRateRanges {
            if range.maxFrameRate >= Double(desiredFPS) {
                device.activeVideoMinFrameDuration = targetFPS
                device.activeVideoMaxFrameDuration = targetFPS
                return
            }
        }
    }

    // MARK: - Recording

    func startRecording(completion: @escaping (Result<URL, CameraError>) -> Void) {
        guard let output = movieOutput, !output.isRecording else { return }

        let filename = "tennis_\(UUID().uuidString).mov"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        currentVideoURL = url
        completionHandler = completion
        recordingStartTime = Date()

        output.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        startTimer()
    }

    func stopRecording() {
        movieOutput?.stopRecording()
        isRecording = false
        stopTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            DispatchQueue.main.async {
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Cleanup

    func teardown() {
        stopRecording()
        captureSession?.stopRunning()
        captureSession = nil
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            if let error {
                self?.completionHandler?(.failure(.recordingFailed(error.localizedDescription)))
            } else {
                self?.completionHandler?(.success(outputFileURL))
            }
            self?.completionHandler = nil
        }
    }
}
```


## FILE: TennisIQ/Services/FeedbackService.swift
```swift
import Foundation
import UIKit

final class FeedbackService {
    static let shared = FeedbackService()
    private init() {}

    func submitFeedback(userID: String?, rating: Int, comment: String) async {
        guard let url = URL(string: "\(AppConstants.API.baseURL)/feedback") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "user_id": userID ?? "anonymous",
            "rating": rating,
            "comment": comment,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            "device_model": UIDevice.current.model,
            "ios_version": UIDevice.current.systemVersion,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Success
            }
        } catch {
            UserDefaults.standard.set(
                try? JSONSerialization.data(withJSONObject: payload),
                forKey: "pending_feedback"
            )
        }
    }
}
```


## FILE: TennisIQ/Services/LiveSwingAnalyzer.swift
```swift
import Foundation
import Combine

struct LiveFeedbackEvent: Identifiable {
    let id = UUID()
    let phase: SwingPhase
    let issue: String
    let severity: ZoneStatus
    let cueText: String
    let timestamp: Date
}

private struct IdealZone {
    let joint: String
    let angleMin: Double
    let angleMax: Double
    let issueKey: String
}

final class LiveSwingAnalyzer: ObservableObject {
    @Published var latestFeedback: LiveFeedbackEvent?
    @Published var currentPhase: SwingPhase = .readyPosition
    @Published var currentFormGrade: String? = nil

    var deviationThreshold: Double = 12
    var minConfidence: Float = 0.4

    private var frameHistory: [FramePoseData] = []
    private let maxHistory = 15
    private var lastEmitTime: Date = .distantPast
    private let emitCooldown: TimeInterval = 2.0

    private let phaseZones: [SwingPhase: [IdealZone]] = [
        .readyPosition: [
            IdealZone(joint: "knee_angle", angleMin: 150, angleMax: 175, issueKey: "knees_bent"),
            IdealZone(joint: "hip_angle", angleMin: 160, angleMax: 180, issueKey: "weight_forward"),
        ],
        .unitTurn: [
            IdealZone(joint: "shoulder_rotation", angleMin: 30, angleMax: 60, issueKey: "shoulders_early"),
            IdealZone(joint: "hip_rotation", angleMin: 20, angleMax: 50, issueKey: "hips_coiled"),
        ],
        .backswing: [
            IdealZone(joint: "elbow_angle", angleMin: 90, angleMax: 120, issueKey: "elbow_up"),
            IdealZone(joint: "wrist_angle", angleMin: 80, angleMax: 110, issueKey: "wrist_lag"),
        ],
        .forwardSwing: [
            IdealZone(joint: "elbow_angle", angleMin: 140, angleMax: 175, issueKey: "extend_arm"),
            IdealZone(joint: "hip_lead", angleMin: 20, angleMax: 50, issueKey: "hip_lead"),
        ],
        .contactPoint: [
            IdealZone(joint: "arm_extension", angleMin: 165, angleMax: 180, issueKey: "contact_front"),
            IdealZone(joint: "wrist_angle", angleMin: 170, angleMax: 185, issueKey: "firm_wrist"),
        ],
        .followThrough: [
            IdealZone(joint: "arm_angle", angleMin: 90, angleMax: 140, issueKey: "finish_high"),
            IdealZone(joint: "body_rotation", angleMin: 60, angleMax: 120, issueKey: "rotate_through"),
        ],
        .recovery: [
            IdealZone(joint: "knee_angle", angleMin: 150, angleMax: 175, issueKey: "split_step"),
        ],
    ]

    private let phaseCues: [String: String] = [
        "weight_forward": "Shift weight to balls of feet",
        "knees_bent": "Bend your knees more",
        "racket_up": "Keep racket in front",
        "shoulders_early": "Start shoulder turn earlier",
        "hips_coiled": "Coil hips with shoulders",
        "racket_back": "Take racket back with turn",
        "elbow_up": "Keep elbow up on backswing",
        "wrist_lag": "Let wrist lag behind",
        "loop_complete": "Finish the backswing loop",
        "accelerate": "Accelerate through contact",
        "extend_arm": "Extend arm toward ball",
        "hip_lead": "Lead with hips",
        "contact_front": "Hit ball in front of body",
        "eyes_on_ball": "Keep eyes on ball",
        "firm_wrist": "Keep wrist firm at contact",
        "finish_high": "Finish over shoulder",
        "rotate_through": "Rotate body through",
        "balance": "Stay balanced",
        "split_step": "Split step for next",
        "return_ready": "Return to ready position",
    ]

    func processFrame(_ frame: FramePoseData) {
        frameHistory.append(frame)
        if frameHistory.count > maxHistory {
            frameHistory.removeFirst()
        }

        let detectedPhase = detectPhase(from: frameHistory)
        currentPhase = detectedPhase

        guard let zones = phaseZones[detectedPhase],
              frameHistory.count >= 3
        else { return }

        let joints = frame.joints
        let jointMap = Dictionary(uniqueKeysWithValues: joints.map { ($0.name, $0) })

        for zone in zones {
            guard let angle = computeAngle(for: zone.joint, joints: joints, jointMap: jointMap, history: frameHistory),
                  angle >= 0
            else { continue }

            let deviation = deviationFromZone(angle, min: zone.angleMin, max: zone.angleMax)
            if deviation > deviationThreshold {
                let severity = severityForDeviation(deviation)
                let cueText = phaseCues[zone.issueKey] ?? "Adjust \(zone.joint)"
                emitIfAllowed(phase: detectedPhase, issue: zone.issueKey, severity: severity, cueText: cueText)
                return
            }
        }
    }

    func reset() {
        frameHistory.removeAll()
        currentPhase = .readyPosition
        latestFeedback = nil
        lastEmitTime = .distantPast
    }

    private func detectPhase(from history: [FramePoseData]) -> SwingPhase {
        guard history.count >= 3 else { return .readyPosition }

        let recent = history.suffix(5)
        let velocities = computeWristVelocities(from: Array(recent))
        let accelerations = computeAccelerations(velocities)

        if let last = velocities.last, let prev = velocities.dropLast().last {
            if last > 0.08 && prev < 0.04 { return .forwardSwing }
            if last > 0.06 && accelerations.last ?? 0 < -0.02 { return .contactPoint }
            if last < -0.03 { return .backswing }
            if last > 0.02 && (velocities.first ?? 0) < 0.01 { return .unitTurn }
        }

        let avgVel = velocities.isEmpty ? 0 : velocities.reduce(0, +) / Double(velocities.count)
        if abs(avgVel) < 0.02 { return .readyPosition }
        if avgVel > 0.03 { return .followThrough }
        return .recovery
    }

    private func computeWristVelocities(from frames: [FramePoseData]) -> [Double] {
        let wristName = Handedness.current.dominantWrist
        var result: [Double] = []
        for i in 1..<frames.count {
            let curr = frames[i].joints.first { $0.name == wristName }
            let prev = frames[i - 1].joints.first { $0.name == wristName }
            guard let c = curr, let p = prev, c.confidence >= minConfidence, p.confidence >= minConfidence else {
                result.append(0)
                continue
            }
            let dx = c.x - p.x
            let dy = c.y - p.y
            result.append(hypot(dx, dy))
        }
        return result
    }

    private func computeAccelerations(_ velocities: [Double]) -> [Double] {
        (1..<velocities.count).map { velocities[$0] - velocities[$0 - 1] }
    }

    private func computeAngle(
        for zoneJoint: String,
        joints: [JointData],
        jointMap: [String: JointData],
        history: [FramePoseData]
    ) -> Double? {
        switch zoneJoint {
        case "knee_angle":
            return angleBetween(
                jointMap["left_hip"], jointMap["left_knee"], jointMap["left_ankle"]
            ) ?? angleBetween(
                jointMap["right_hip"], jointMap["right_knee"], jointMap["right_ankle"]
            )
        case "hip_angle":
            return angleBetween(
                jointMap["left_shoulder"], jointMap["left_hip"], jointMap["left_knee"]
            ) ?? angleBetween(
                jointMap["right_shoulder"], jointMap["right_hip"], jointMap["right_knee"]
            )
        case "elbow_angle":
            return angleBetween(
                jointMap["left_shoulder"], jointMap["left_elbow"], jointMap["left_wrist"]
            ) ?? angleBetween(
                jointMap["right_shoulder"], jointMap["right_elbow"], jointMap["right_wrist"]
            )
        case "wrist_angle":
            return angleBetween(
                jointMap["right_elbow"], jointMap["right_wrist"], jointMap["right_shoulder"]
            ) ?? angleBetween(
                jointMap["left_elbow"], jointMap["left_wrist"], jointMap["left_shoulder"]
            )
        case "shoulder_rotation":
            return shoulderRotationAngle(jointMap)
        case "hip_rotation":
            return hipRotationAngle(jointMap)
        case "arm_extension", "arm_angle":
            return angleBetween(
                jointMap["right_shoulder"], jointMap["right_elbow"], jointMap["right_wrist"]
            ) ?? angleBetween(
                jointMap["left_shoulder"], jointMap["left_elbow"], jointMap["left_wrist"]
            )
        case "hip_lead", "body_rotation":
            return shoulderRotationAngle(jointMap)
        default:
            return nil
        }
    }

    private func angleBetween(_ a: JointData?, _ b: JointData?, _ c: JointData?) -> Double? {
        guard let a = a, let b = b, let c = c,
              a.confidence >= minConfidence, b.confidence >= minConfidence, c.confidence >= minConfidence
        else { return nil }
        let ba = (ax: a.x - b.x, ay: a.y - b.y)
        let bc = (cx: c.x - b.x, cy: c.y - b.y)
        let dot = ba.ax * bc.cx + ba.ay * bc.cy
        let cross = ba.ax * bc.cy - ba.ay * bc.cx
        let angle = atan2(cross, dot) * 180 / .pi
        return angle >= 0 ? angle : angle + 360
    }

    private func shoulderRotationAngle(_ map: [String: JointData]) -> Double? {
        guard let l = map["left_shoulder"], let r = map["right_shoulder"],
              let nose = map["nose"],
              l.confidence >= minConfidence, r.confidence >= minConfidence, nose.confidence >= minConfidence
        else { return nil }
        let midX = (l.x + r.x) / 2
        let dx = r.x - l.x
        let dy = r.y - l.y
        let angle = atan2(dy, dx) * 180 / .pi
        return angle >= 0 ? angle : angle + 360
    }

    private func hipRotationAngle(_ map: [String: JointData]) -> Double? {
        guard let l = map["left_hip"], let r = map["right_hip"],
              l.confidence >= minConfidence, r.confidence >= minConfidence
        else { return nil }
        let dx = r.x - l.x
        let dy = r.y - l.y
        let angle = atan2(dy, dx) * 180 / .pi
        return angle >= 0 ? angle : angle + 360
    }

    private func deviationFromZone(_ angle: Double, min minA: Double, max maxA: Double) -> Double {
        if angle >= minA && angle <= maxA { return 0 }
        if angle < minA { return minA - angle }
        return angle - maxA
    }

    private func severityForDeviation(_ deviation: Double) -> ZoneStatus {
        if deviation > deviationThreshold * 2 { return .outOfZone }
        if deviation > deviationThreshold { return .warning }
        return .inZone
    }

    private func emitIfAllowed(phase: SwingPhase, issue: String, severity: ZoneStatus, cueText: String) {
        let now = Date()
        guard now.timeIntervalSince(lastEmitTime) >= emitCooldown else { return }
        lastEmitTime = now
        let event = LiveFeedbackEvent(phase: phase, issue: issue, severity: severity, cueText: cueText, timestamp: now)
        DispatchQueue.main.async { [weak self] in
            self?.latestFeedback = event
        }
    }
}
```


## FILE: TennisIQ/Services/OverlayRenderer.swift
```swift
import Foundation
import SwiftUI
import UIKit
import CoreGraphics
import AVFoundation

/// Renders pose skeleton overlays and coaching annotations on video frames
final class OverlayRenderer {
    let theme: AppTheme

    init(theme: AppTheme = DesignSystem.current) {
        self.theme = theme
    }

    // MARK: - Skeleton Connections

    private static let boneConnections: [(String, String)] = [
        ("left_shoulder", "right_shoulder"),
        ("left_shoulder", "left_elbow"),
        ("left_elbow", "left_wrist"),
        ("right_shoulder", "right_elbow"),
        ("right_elbow", "right_wrist"),
        ("left_shoulder", "left_hip"),
        ("right_shoulder", "right_hip"),
        ("left_hip", "right_hip"),
        ("left_hip", "left_knee"),
        ("left_knee", "left_ankle"),
        ("right_hip", "right_knee"),
        ("right_knee", "right_ankle"),
        ("nose", "left_shoulder"),
        ("nose", "right_shoulder"),
    ]

    // MARK: - Draw Skeleton on Frame

    func drawSkeleton(
        on image: UIImage,
        poseData: FramePoseData,
        highlightJoints: Set<String> = [],
        strokeResult: StrokeResult? = nil
    ) -> UIImage {
        let size = image.size

        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return image }

        image.draw(at: .zero)

        let jointMap = Dictionary(uniqueKeysWithValues: poseData.joints.map { ($0.name, $0) })

        // Draw bone connections
        for (startName, endName) in Self.boneConnections {
            guard let start = jointMap[startName], let end = jointMap[endName] else { continue }

            let startPoint = denormalize(x: start.x, y: start.y, in: size)
            let endPoint = denormalize(x: end.x, y: end.y, in: size)

            let isHighlighted = highlightJoints.contains(startName) || highlightJoints.contains(endName)
            let lineColor = isHighlighted ? uiColor(theme.skeletonWarning) : uiColor(theme.skeletonStroke)

            context.setStrokeColor(lineColor.cgColor)
            context.setLineWidth(isHighlighted ? 4.0 : 2.5)
            context.setLineCap(.round)

            // Glow effect
            context.setShadow(offset: .zero, blur: 8, color: lineColor.withAlphaComponent(0.6).cgColor)

            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }

        context.setShadow(offset: .zero, blur: 0)

        // Draw joint dots
        for joint in poseData.joints {
            let point = denormalize(x: joint.x, y: joint.y, in: size)
            let isHighlighted = highlightJoints.contains(joint.name)
            let dotRadius: CGFloat = isHighlighted ? 6 : 4
            let dotColor = isHighlighted ? uiColor(theme.skeletonWarning) : uiColor(theme.skeletonCorrect)

            context.setFillColor(dotColor.cgColor)
            context.fillEllipse(in: CGRect(
                x: point.x - dotRadius,
                y: point.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            ))
        }

        // Draw angle annotations if available
        if let result = strokeResult {
            drawAngleAnnotations(context: context, jointMap: jointMap, result: result, size: size)
        }

        let resultImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resultImage
    }

    // MARK: - Angle Annotations

    private func drawAngleAnnotations(
        context: CGContext,
        jointMap: [String: JointData],
        result: StrokeResult,
        size: CGSize
    ) {
        for angleStr in result.overlayInstructions.anglesToHighlight {
            // Parse "right_elbow: 142° (ideal: 155-170°)"
            let parts = angleStr.split(separator: ":")
            guard parts.count >= 2 else { continue }

            let jointName = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let label = String(parts[1]).trimmingCharacters(in: .whitespaces)

            guard let joint = jointMap[jointName] else { continue }
            let point = denormalize(x: joint.x, y: joint.y, in: size)

            let labelRect = CGRect(
                x: point.x + 12,
                y: point.y - 20,
                width: 160,
                height: 36
            )

            // Background pill
            let pillPath = UIBezierPath(roundedRect: labelRect, cornerRadius: 8)
            context.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
            context.addPath(pillPath.cgPath)
            context.fillPath()

            // Text
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: uiColor(theme.angleAnnotation),
            ]
            let nsString = label as NSString
            nsString.draw(
                in: labelRect.insetBy(dx: 8, dy: 8),
                withAttributes: attrs
            )
        }
    }

    // MARK: - Trajectory Line

    func drawTrajectoryLine(
        on image: UIImage,
        frames: [FramePoseData],
        jointName: String = "right_wrist"
    ) -> UIImage {
        let size = image.size

        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        image.draw(at: .zero)
        guard let context = UIGraphicsGetCurrentContext() else { return image }

        let points = frames.compactMap { frame -> CGPoint? in
            guard let joint = frame.joints.first(where: { $0.name == jointName }) else { return nil }
            return denormalize(x: joint.x, y: joint.y, in: size)
        }

        guard points.count >= 2 else {
            UIGraphicsEndImageContext()
            return image
        }

        context.setStrokeColor(uiColor(theme.trajectoryLine).cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setShadow(offset: .zero, blur: 6, color: uiColor(theme.trajectoryLine).withAlphaComponent(0.5).cgColor)

        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()

        let resultImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resultImage
    }

    // MARK: - Swing Path

    func drawSwingPath(
        on image: UIImage,
        pathPoints: [[Double]],
        planeAngle: Double?,
        annotations: [PathAnnotation]?
    ) -> UIImage {
        let size = image.size

        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        image.draw(at: .zero)
        guard let context = UIGraphicsGetCurrentContext() else { return image }

        let points = pathPoints.compactMap { coord -> CGPoint? in
            guard coord.count >= 2 else { return nil }
            return denormalize(x: coord[0], y: coord[1], in: size)
        }

        guard points.count >= 2 else {
            UIGraphicsEndImageContext()
            return image
        }

        if let angle = planeAngle {
            drawSwingPlaneReference(context: context, angle: angle, size: size)
        }

        let pathColor = uiColor(theme.success)
        context.setStrokeColor(pathColor.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(8.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setShadow(offset: .zero, blur: 12, color: pathColor.withAlphaComponent(0.4).cgColor)

        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()

        context.setShadow(offset: .zero, blur: 0)
        context.setStrokeColor(pathColor.cgColor)
        context.setLineWidth(3.0)
        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()

        let resultImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resultImage
    }

    private func drawSwingPlaneReference(context: CGContext, angle: Double, size: CGSize) {
        let centerX = size.width * 0.5
        let centerY = size.height * 0.5
        let length = max(size.width, size.height)
        let radians = angle * .pi / 180.0

        let dx = cos(radians) * length * 0.5
        let dy = sin(radians) * length * 0.5

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.15).cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [6, 4])

        context.move(to: CGPoint(x: centerX - dx, y: centerY + dy))
        context.addLine(to: CGPoint(x: centerX + dx, y: centerY - dy))
        context.strokePath()

        context.setLineDash(phase: 0, lengths: [])
    }

    // MARK: - Pro Ghost Overlay

    func drawProGhost(
        on image: UIImage,
        proJoints: [JointData],
        opacity: CGFloat = 0.4
    ) -> UIImage {
        let size = image.size

        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        image.draw(at: .zero)
        guard let context = UIGraphicsGetCurrentContext() else { return image }

        let jointMap = Dictionary(uniqueKeysWithValues: proJoints.map { ($0.name, $0) })
        let ghostColor = UIColor(red: 0.83, green: 0.58, blue: 0.16, alpha: opacity)

        for (startName, endName) in Self.boneConnections {
            guard let start = jointMap[startName], let end = jointMap[endName] else { continue }

            let startPoint = denormalize(x: start.x, y: start.y, in: size)
            let endPoint = denormalize(x: end.x, y: end.y, in: size)

            context.setStrokeColor(ghostColor.cgColor)
            context.setLineWidth(2.5)
            context.setLineCap(.round)
            context.setShadow(offset: .zero, blur: 6, color: ghostColor.withAlphaComponent(0.3).cgColor)

            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }

        context.setShadow(offset: .zero, blur: 0)

        for joint in proJoints {
            let point = denormalize(x: joint.x, y: joint.y, in: size)
            context.setFillColor(ghostColor.cgColor)
            context.fillEllipse(in: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
        }

        let resultImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resultImage
    }

    // MARK: - Helpers

    private func denormalize(x: Double, y: Double, in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: (1.0 - y) * size.height)
    }

    private func uiColor(_ color: any ShapeStyle) -> UIColor {
        .white
    }

    private func uiColor(_ color: Color) -> UIColor {
        UIColor(color)
    }
}
```


## FILE: TennisIQ/Services/PoseEstimationService.swift
```swift
import Foundation
import Vision
import AVFoundation
import UIKit
import Combine

/// Processes video frames through Apple Vision to extract body pose data
final class PoseEstimationService: ObservableObject {
    @Published var progress: Double = 0
    @Published var isProcessing = false
    @Published var error: PoseError?

    private let processingQueue = DispatchQueue(label: "com.tennisiq.pose", qos: .userInitiated)

    enum PoseError: LocalizedError {
        case videoLoadFailed
        case noPersonDetected
        case processingFailed(String)

        var errorDescription: String? {
            switch self {
            case .videoLoadFailed: return "Failed to load video for analysis."
            case .noPersonDetected: return "No person detected in the video. Make sure you're visible in frame."
            case .processingFailed(let msg): return "Processing failed: \(msg)"
            }
        }
    }

    struct ExtractionResult {
        let frames: [FramePoseData]
        let keyFrames: [(timestamp: Double, image: UIImage)]
        let duration: Double
        let detectedStrokes: [DetectedStroke]
    }

    // MARK: - Main Extraction Pipeline

    func extractPoses(from videoURL: URL) async throws -> ExtractionResult {
        await MainActor.run {
            isProcessing = true
            progress = 0
        }

        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }

        let asset = AVURLAsset(url: videoURL)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw PoseError.videoLoadFailed
        }

        let duration = try await asset.load(.duration).seconds
        let nominalFPS = try await videoTrack.load(.nominalFrameRate)
        let totalFrames = Int(duration * Double(nominalFPS))

        // Sample every Nth frame to achieve target processing FPS
        let sampleInterval = max(1, Int(nominalFPS) / AppConstants.Camera.processingFPS)

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)
        reader.startReading()

        var allFrames: [FramePoseData] = []
        var keyFrames: [(timestamp: Double, image: UIImage)] = []
        var frameIndex = 0
        var previousWristVelocity: Double = 0
        var lastStrokeTimestamp: Double = -10
        var recentVelocities: [Double] = []

        while reader.status == .reading, let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            frameIndex += 1

            if frameIndex % sampleInterval != 0 { continue }
            let currentFrameIndex = frameIndex

            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }

            if let poseData = try await detectPose(in: pixelBuffer, frameIndex: currentFrameIndex, timestamp: timestamp) {
                allFrames.append(poseData)

                let wristVelocity = calculateWristVelocity(current: poseData, previous: allFrames.dropLast().last)
                recentVelocities.append(wristVelocity)
                if recentVelocities.count > 10 { recentVelocities.removeFirst() }

                let avgVelocity = recentVelocities.reduce(0, +) / Double(recentVelocities.count)
                let isHighVelocity = wristVelocity > 0.03 && wristVelocity > avgVelocity * 1.8
                let isDeceleration = previousWristVelocity > 0.03 && wristVelocity < previousWristVelocity * 0.6
                let isStrokeApex = (isHighVelocity || isDeceleration) && (timestamp - lastStrokeTimestamp) > minTimeBetweenStrokes
                previousWristVelocity = wristVelocity

                if isStrokeApex && keyFrames.count < AppConstants.Analysis.maxKeyFrames {
                    let image = imageFromPixelBuffer(pixelBuffer)
                    keyFrames.append((timestamp: timestamp, image: image))
                    lastStrokeTimestamp = timestamp
                }
            }

            await MainActor.run {
                self.progress = Double(currentFrameIndex) / Double(totalFrames)
            }
        }

        guard !allFrames.isEmpty else {
            throw PoseError.noPersonDetected
        }

        let detector = StrokeDetector()
        let detectedStrokes = detector.detectStrokes(frames: allFrames)

        if !detectedStrokes.isEmpty {
            var strokeKeyFrames: [(timestamp: Double, image: UIImage)] = []
            for stroke in detectedStrokes {
                let contactTime = stroke.contactTimestamp
                if let existingKF = keyFrames.first(where: { abs($0.timestamp - contactTime) < 0.2 }) {
                    strokeKeyFrames.append(existingKF)
                }
            }
            if !strokeKeyFrames.isEmpty {
                keyFrames = strokeKeyFrames + keyFrames.filter { kf in
                    !strokeKeyFrames.contains(where: { abs($0.timestamp - kf.timestamp) < 0.5 })
                }
            }
        }

        if keyFrames.count < 5 {
            keyFrames = try await extractEvenlySpacedKeyFrames(from: videoURL, count: 10, duration: duration)
        }

        return ExtractionResult(frames: allFrames, keyFrames: keyFrames, duration: duration, detectedStrokes: detectedStrokes)
    }

    // MARK: - Pose Detection

    private func detectPose(in pixelBuffer: CVPixelBuffer, frameIndex: Int, timestamp: Double) async throws -> FramePoseData? {
        let request = VNDetectHumanBodyPoseRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else { return nil }

        var joints: [JointData] = []
        for jointName in JointMapping.allJoints {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > AppConstants.Analysis.poseConfidenceThreshold else { continue }

            joints.append(JointData(
                name: JointMapping.canonicalName(for: jointName),
                x: Double(point.location.x),
                y: Double(point.location.y),
                confidence: point.confidence
            ))
        }

        guard joints.count >= 8 else { return nil }

        let avgConfidence = joints.map(\.confidence).reduce(0, +) / Float(joints.count)

        return FramePoseData(
            frameIndex: frameIndex,
            timestamp: timestamp,
            joints: joints,
            confidence: avgConfidence
        )
    }

    // MARK: - Stroke Apex Detection

    private let minTimeBetweenStrokes: Double = 1.5

    private func calculateWristVelocity(current: FramePoseData, previous: FramePoseData?) -> Double {
        guard let prev = previous else { return 0 }

        let wristName = Handedness.current.dominantWrist
        let currentWrist = current.joints.first { $0.name == wristName }
        let prevWrist = prev.joints.first { $0.name == wristName }

        guard let cw = currentWrist, let pw = prevWrist else { return 0 }

        let dx = cw.x - pw.x
        let dy = cw.y - pw.y
        let dt = current.timestamp - prev.timestamp

        guard dt > 0 else { return 0 }
        return sqrt(dx * dx + dy * dy) / dt
    }

    // MARK: - Key Frame Extraction

    private func extractEvenlySpacedKeyFrames(from url: URL, count: Int, duration: Double) async throws -> [(timestamp: Double, image: UIImage)] {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 480)

        let interval = duration / Double(count + 1)
        var results: [(timestamp: Double, image: UIImage)] = []

        for i in 1...count {
            let time = CMTime(seconds: interval * Double(i), preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: time)
                results.append((timestamp: time.seconds, image: UIImage(cgImage: cgImage)))
            } catch {
                continue
            }
        }

        return results
    }

    // MARK: - Helpers

    private func imageFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
}
```


## FILE: TennisIQ/Services/ProComparisonService.swift
```swift
import Foundation

struct ProPlayer: Identifiable {
    let id: String
    let name: String
    let icon: String
    let strokes: [StrokeType]
}

final class ProComparisonService {
    private static let pros: [ProPlayer] = [
        ProPlayer(id: "federer", name: "Federer", icon: "🎾", strokes: [.forehand]),
        ProPlayer(id: "djokovic", name: "Djokovic", icon: "🏆", strokes: [.backhand]),
        ProPlayer(id: "serena", name: "Serena", icon: "👑", strokes: [.serve])
    ]

    func availablePros(for strokeType: StrokeType) -> [ProPlayer] {
        ProComparisonService.pros.filter { $0.strokes.contains(strokeType) }
    }

    func getProPoseData(proName: String, stroke: StrokeType, phase: SwingPhase) -> [JointData]? {
        let baseName = "\(proName.lowercased())_\(stroke.rawValue)_\(phase.rawValue)"
        guard let url = Bundle.main.url(
            forResource: baseName,
            withExtension: "json",
            subdirectory: "ProPoseData"
        ) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([JointData].self, from: data)
    }
}
```


## FILE: TennisIQ/Services/ShareService.swift
```swift
import UIKit
import AVFoundation
import CoreGraphics

final class ShareService {
    static let shared = ShareService()
    private init() {}

    func generateShareImage(
        grade: String,
        strokeType: String,
        joints: [JointData],
        videoSize: CGSize
    ) -> UIImage? {
        let canvasSize = CGSize(width: 1080, height: 1920)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { ctx in
            let context = ctx.cgContext

            UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            drawSkeletonOverlay(context: context, joints: joints, canvasSize: canvasSize, videoSize: videoSize)
            drawGradeBadge(context: context, grade: grade, canvasSize: canvasSize)
            drawStrokeLabel(context: context, strokeType: strokeType, canvasSize: canvasSize)
            drawWatermark(context: context, canvasSize: canvasSize)
        }
    }

    private func drawSkeletonOverlay(context: CGContext, joints: [JointData], canvasSize: CGSize, videoSize: CGSize) {
        let headJoints: Set<String> = ["nose", "left_eye", "right_eye", "left_ear", "right_ear"]
        let bodyJoints = joints.filter { !headJoints.contains($0.name) }

        let bones: [(String, String)] = [
            ("left_shoulder", "right_shoulder"),
            ("left_shoulder", "left_elbow"), ("left_elbow", "left_wrist"),
            ("right_shoulder", "right_elbow"), ("right_elbow", "right_wrist"),
            ("left_shoulder", "left_hip"), ("right_shoulder", "right_hip"),
            ("left_hip", "right_hip"),
            ("left_hip", "left_knee"), ("left_knee", "left_ankle"),
            ("right_hip", "right_knee"), ("right_knee", "right_ankle")
        ]

        let map = Dictionary(uniqueKeysWithValues: bodyJoints.map { ($0.name, $0) })

        let limeGreen = UIColor(red: 0.784, green: 1.0, blue: 0.0, alpha: 0.9)
        context.setStrokeColor(limeGreen.cgColor)
        context.setLineWidth(4.0)
        context.setLineCap(.round)

        for (a, b) in bones {
            guard let ja = map[a], let jb = map[b] else { continue }
            let ptA = toCanvas(ja, canvasSize: canvasSize)
            let ptB = toCanvas(jb, canvasSize: canvasSize)
            context.move(to: ptA)
            context.addLine(to: ptB)
        }
        context.strokePath()

        let dotColor = UIColor(red: 0.784, green: 1.0, blue: 0.0, alpha: 1.0)
        context.setFillColor(dotColor.cgColor)
        for joint in bodyJoints {
            let pt = toCanvas(joint, canvasSize: canvasSize)
            context.fillEllipse(in: CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12))
        }
    }

    private func toCanvas(_ joint: JointData, canvasSize: CGSize) -> CGPoint {
        CGPoint(
            x: joint.y * canvasSize.width,
            y: joint.x * canvasSize.height
        )
    }

    private func drawGradeBadge(context: CGContext, grade: String, canvasSize: CGSize) {
        let badgeSize: CGFloat = 120
        let padding: CGFloat = 40
        let badgeRect = CGRect(
            x: canvasSize.width - badgeSize - padding,
            y: padding,
            width: badgeSize,
            height: badgeSize
        )

        let gradeColor: UIColor = switch grade.prefix(1) {
        case "A": UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1)
        case "B": UIColor(red: 0.784, green: 1.0, blue: 0.0, alpha: 1)
        case "C": UIColor(red: 1.0, green: 0.75, blue: 0.0, alpha: 1)
        default: UIColor(red: 1.0, green: 0.36, blue: 0.36, alpha: 1)
        }

        context.setFillColor(gradeColor.withAlphaComponent(0.15).cgColor)
        let path = UIBezierPath(roundedRect: badgeRect, cornerRadius: 24)
        context.addPath(path.cgPath)
        context.fillPath()

        context.setStrokeColor(gradeColor.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(2)
        context.addPath(path.cgPath)
        context.strokePath()

        let gradeFont = UIFont.systemFont(ofSize: 56, weight: .black)
        let gradeAttrs: [NSAttributedString.Key: Any] = [
            .font: gradeFont,
            .foregroundColor: gradeColor
        ]
        let gradeString = NSString(string: grade)
        let gradeSize = gradeString.size(withAttributes: gradeAttrs)
        let gradeOrigin = CGPoint(
            x: badgeRect.midX - gradeSize.width / 2,
            y: badgeRect.midY - gradeSize.height / 2
        )
        gradeString.draw(at: gradeOrigin, withAttributes: gradeAttrs)
    }

    private func drawStrokeLabel(context: CGContext, strokeType: String, canvasSize: CGSize) {
        let font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]
        let string = NSString(string: strokeType.uppercased())
        let size = string.size(withAttributes: attrs)
        let origin = CGPoint(x: 40, y: 40)

        let bgRect = CGRect(x: origin.x - 12, y: origin.y - 6, width: size.width + 24, height: size.height + 12)
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 8)
        context.addPath(bgPath.cgPath)
        context.fillPath()

        string.draw(at: origin, withAttributes: attrs)
    }

    private func drawWatermark(context: CGContext, canvasSize: CGSize) {
        let watermarkFont = UIFont.systemFont(ofSize: 18, weight: .medium)
        let watermarkAttrs: [NSAttributedString.Key: Any] = [
            .font: watermarkFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.6)
        ]
        let watermarkText = NSString(string: "Analyzed by Tennis Coach AI")
        let watermarkSize = watermarkText.size(withAttributes: watermarkAttrs)
        let watermarkOrigin = CGPoint(
            x: canvasSize.width / 2 - watermarkSize.width / 2,
            y: canvasSize.height - watermarkSize.height - 60
        )

        let bgRect = CGRect(
            x: watermarkOrigin.x - 16,
            y: watermarkOrigin.y - 8,
            width: watermarkSize.width + 32,
            height: watermarkSize.height + 16
        )
        context.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: 20)
        context.addPath(bgPath.cgPath)
        context.fillPath()

        watermarkText.draw(at: watermarkOrigin, withAttributes: watermarkAttrs)
    }

    func presentShareSheet(image: UIImage, from viewController: UIViewController) {
        let items: [Any] = [
            image,
            "My tennis stroke analyzed by AI! 🎾 Download Tennis Coach AI free on the App Store."
        ]
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.excludedActivityTypes = [.addToReadingList, .assignToContact, .openInIBooks]
        viewController.present(activityVC, animated: true)
    }
}
```


## FILE: TennisIQ/Services/StrokeDetector.swift
```swift
import Foundation

struct DetectedStroke: Codable {
    let type: String
    let contactTimestamp: Double
    let phases: [String: DetectedPhase]
}

struct DetectedPhase: Codable {
    let timestamp: Double
    let angles: [String: MeasuredAngle]
}

struct MeasuredAngle: Codable {
    let value: Double
    let label: String
    let visible: Bool

    enum CodingKeys: String, CodingKey {
        case value, label, visible
    }
}

final class StrokeDetector {
    private let minConfidence: Float = 0.3
    private let minTimeBetweenStrokes: Double = 2.0
    private let velocityThreshold: Double = 0.025
    private let handedness: Handedness

    init(handedness: Handedness = .current) {
        self.handedness = handedness
    }

    func detectStrokes(frames: [FramePoseData]) -> [DetectedStroke] {
        guard frames.count >= 10 else { return [] }

        let sorted = frames.sorted { $0.timestamp < $1.timestamp }
        let velocities = computeWristVelocities(sorted)
        let contactIndices = findContactPeaks(velocities: velocities, frames: sorted)

        return contactIndices.compactMap { contactIdx in
            buildStroke(contactIndex: contactIdx, frames: sorted, velocities: velocities)
        }
    }

    private func computeWristVelocities(_ frames: [FramePoseData]) -> [Double] {
        let wristName = handedness.dominantWrist
        var velocities: [Double] = [0]

        for i in 1..<frames.count {
            let curr = frames[i].joints.first { $0.name == wristName && $0.confidence >= minConfidence }
            let prev = frames[i - 1].joints.first { $0.name == wristName && $0.confidence >= minConfidence }

            guard let c = curr, let p = prev else {
                velocities.append(0)
                continue
            }

            let dt = frames[i].timestamp - frames[i - 1].timestamp
            guard dt > 0 else {
                velocities.append(0)
                continue
            }

            let dist = hypot(c.x - p.x, c.y - p.y)
            velocities.append(dist / dt)
        }

        return smoothVelocities(velocities, windowSize: 3)
    }

    private func smoothVelocities(_ v: [Double], windowSize: Int) -> [Double] {
        guard v.count >= windowSize else { return v }
        let half = windowSize / 2
        return v.indices.map { i in
            let lo = max(0, i - half)
            let hi = min(v.count - 1, i + half)
            let slice = v[lo...hi]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    private func findContactPeaks(velocities: [Double], frames: [FramePoseData]) -> [Int] {
        guard velocities.count >= 5 else { return [] }

        let avgVelocity = velocities.reduce(0, +) / Double(velocities.count)
        let dynamicThreshold = max(velocityThreshold, avgVelocity * 2.0)

        var peaks: [Int] = []
        var lastPeakTimestamp: Double = -100

        for i in 2..<(velocities.count - 2) {
            let isPeak = velocities[i] > velocities[i - 1] &&
                         velocities[i] > velocities[i - 2] &&
                         velocities[i] >= velocities[i + 1] &&
                         velocities[i] > dynamicThreshold

            let timeSinceLast = frames[i].timestamp - lastPeakTimestamp

            if isPeak && timeSinceLast > minTimeBetweenStrokes {
                peaks.append(i)
                lastPeakTimestamp = frames[i].timestamp
            }
        }

        return peaks
    }

    private func buildStroke(contactIndex: Int, frames: [FramePoseData], velocities: [Double]) -> DetectedStroke? {
        let contactFrame = frames[contactIndex]
        let contactTime = contactFrame.timestamp

        let forwardSwingIdx = scanBackward(from: contactIndex, frames: frames, velocities: velocities, condition: { v in v < velocities[contactIndex] * 0.5 })
        let backswingIdx = scanBackward(from: forwardSwingIdx, frames: frames, velocities: velocities, condition: { v in v < 0.01 })
        let unitTurnIdx = scanBackwardForShoulderChange(from: backswingIdx, frames: frames)
        let readyIdx = scanBackward(from: unitTurnIdx, frames: frames, velocities: velocities, condition: { v in v < 0.005 })
        let followThroughIdx = scanForward(from: contactIndex, frames: frames, velocities: velocities, condition: { v in v < velocities[contactIndex] * 0.3 })
        let recoveryIdx = scanForward(from: followThroughIdx, frames: frames, velocities: velocities, condition: { v in v < 0.01 })

        let readyTime = frames[readyIdx].timestamp
        let unitTurnTime = frames[unitTurnIdx].timestamp
        let backswingTime = frames[backswingIdx].timestamp
        let forwardSwingTime = frames[forwardSwingIdx].timestamp
        let followThroughTime = frames[followThroughIdx].timestamp
        let recoveryTime = frames[recoveryIdx].timestamp

        guard readyTime < unitTurnTime,
              unitTurnTime <= backswingTime,
              backswingTime <= forwardSwingTime,
              forwardSwingTime < contactTime,
              contactTime < followThroughTime,
              followThroughTime <= recoveryTime
        else {
            let fallbackPhases = buildFallbackPhases(contactTime: contactTime, contactFrame: contactFrame)
            let strokeType = inferStrokeType(at: contactIndex, frames: frames)
            return DetectedStroke(type: strokeType, contactTimestamp: contactTime, phases: fallbackPhases)
        }

        let phaseFrames: [(String, Int, Double)] = [
            ("ready_position", readyIdx, readyTime),
            ("unit_turn", unitTurnIdx, unitTurnTime),
            ("backswing", backswingIdx, backswingTime),
            ("forward_swing", forwardSwingIdx, forwardSwingTime),
            ("contact_point", contactIndex, contactTime),
            ("follow_through", followThroughIdx, followThroughTime),
            ("recovery", recoveryIdx, recoveryTime),
        ]

        var phases: [String: DetectedPhase] = [:]
        for (name, idx, time) in phaseFrames {
            let angles = measureAngles(frame: frames[idx])
            phases[name] = DetectedPhase(timestamp: time, angles: angles)
        }

        let strokeType = inferStrokeType(at: contactIndex, frames: frames)
        return DetectedStroke(type: strokeType, contactTimestamp: contactTime, phases: phases)
    }

    private func buildFallbackPhases(contactTime: Double, contactFrame: FramePoseData) -> [String: DetectedPhase] {
        let offsets: [(String, Double)] = [
            ("ready_position", -1.5),
            ("unit_turn", -1.2),
            ("backswing", -0.8),
            ("forward_swing", -0.4),
            ("contact_point", 0),
            ("follow_through", 0.3),
            ("recovery", 0.8),
        ]

        var phases: [String: DetectedPhase] = [:]
        let angles = measureAngles(frame: contactFrame)
        for (name, offset) in offsets {
            phases[name] = DetectedPhase(timestamp: max(0, contactTime + offset), angles: angles)
        }
        return phases
    }

    private func scanBackward(from startIdx: Int, frames: [FramePoseData], velocities: [Double], condition: (Double) -> Bool) -> Int {
        var idx = startIdx
        while idx > 0 {
            idx -= 1
            if condition(velocities[idx]) { return idx }
        }
        return max(0, startIdx - 3)
    }

    private func scanForward(from startIdx: Int, frames: [FramePoseData], velocities: [Double], condition: (Double) -> Bool) -> Int {
        var idx = startIdx
        while idx < frames.count - 1 {
            idx += 1
            if condition(velocities[idx]) { return idx }
        }
        return min(frames.count - 1, startIdx + 3)
    }

    private func scanBackwardForShoulderChange(from startIdx: Int, frames: [FramePoseData]) -> Int {
        var idx = startIdx
        let startRotation = shoulderRotation(frame: frames[startIdx])

        while idx > 0 {
            idx -= 1
            let rotation = shoulderRotation(frame: frames[idx])
            if let sr = startRotation, let cr = rotation, abs(sr - cr) > 10 {
                return idx
            }
        }
        return max(0, startIdx - 2)
    }

    private func shoulderRotation(frame: FramePoseData) -> Double? {
        let map = Dictionary(uniqueKeysWithValues: frame.joints.map { ($0.name, $0) })
        guard let ls = map["left_shoulder"], let rs = map["right_shoulder"],
              ls.confidence >= minConfidence, rs.confidence >= minConfidence else { return nil }
        let dx = rs.x - ls.x
        let dy = rs.y - ls.y
        return atan2(abs(dy), abs(dx)) * 180 / .pi
    }

    private func inferStrokeType(at idx: Int, frames: [FramePoseData]) -> String {
        let frame = frames[idx]
        let map = Dictionary(uniqueKeysWithValues: frame.joints.map { ($0.name, $0) })

        let wristName = handedness.dominantWrist
        guard let wrist = map[wristName],
              let nose = map["nose"],
              wrist.confidence >= minConfidence,
              nose.confidence >= minConfidence else {
            return "forehand"
        }

        if wrist.y > nose.y + 0.15 {
            return "serve"
        }

        let isRight = handedness == .right
        let midX = (map["left_shoulder"]?.x ?? 0.5 + (map["right_shoulder"]?.x ?? 0.5)) / 2

        if isRight {
            return wrist.x > midX ? "forehand" : "backhand"
        } else {
            return wrist.x < midX ? "forehand" : "backhand"
        }
    }

    func measureAngles(frame: FramePoseData) -> [String: MeasuredAngle] {
        let map = Dictionary(uniqueKeysWithValues: frame.joints.map { ($0.name, $0) })
        let side = handedness == .right ? "right" : "left"
        let otherSide = handedness == .right ? "left" : "right"

        var angles: [String: MeasuredAngle] = [:]

        if let a = computeAngle(a: map["\(side)_shoulder"], b: map["\(side)_elbow"], c: map["\(side)_wrist"]) {
            angles["elbow_angle"] = MeasuredAngle(value: round(a), label: "Elbow: \(Int(a))°", visible: true)
        } else {
            angles["elbow_angle"] = MeasuredAngle(value: 0, label: "Elbow: NOT_VISIBLE", visible: false)
        }

        if let a = computeAngle(a: map["\(side)_hip"], b: map["\(side)_knee"], c: map["\(side)_ankle"]) {
            angles["knee_angle"] = MeasuredAngle(value: round(a), label: "Knee: \(Int(a))°", visible: true)
        } else {
            angles["knee_angle"] = MeasuredAngle(value: 0, label: "Knee: NOT_VISIBLE", visible: false)
        }

        if let a = computeAngle(a: map["\(side)_shoulder"], b: map["\(side)_hip"], c: map["\(side)_knee"]) {
            angles["hip_angle"] = MeasuredAngle(value: round(a), label: "Hip: \(Int(a))°", visible: true)
        } else {
            angles["hip_angle"] = MeasuredAngle(value: 0, label: "Hip: NOT_VISIBLE", visible: false)
        }

        if let ls = map["left_shoulder"], let rs = map["right_shoulder"],
           let lh = map["left_hip"], let rh = map["right_hip"],
           ls.confidence >= minConfidence, rs.confidence >= minConfidence,
           lh.confidence >= minConfidence, rh.confidence >= minConfidence {
            let shoulderDx = rs.x - ls.x
            let shoulderDy = rs.y - ls.y
            let hipDx = rh.x - lh.x
            let hipDy = rh.y - lh.y
            let shoulderAngle = atan2(shoulderDy, shoulderDx)
            let hipAngle = atan2(hipDy, hipDx)
            let rotation = abs(shoulderAngle - hipAngle) * 180 / .pi
            angles["shoulder_rotation"] = MeasuredAngle(value: round(rotation), label: "Shoulder rotation: \(Int(rotation))°", visible: true)
        } else {
            angles["shoulder_rotation"] = MeasuredAngle(value: 0, label: "Shoulder rotation: NOT_VISIBLE", visible: false)
        }

        if let shoulder = map["\(side)_shoulder"], let wrist = map["\(side)_wrist"],
           shoulder.confidence >= minConfidence, wrist.confidence >= minConfidence {
            let ext = hypot(wrist.x - shoulder.x, wrist.y - shoulder.y)
            let normalized = min(180, ext * 500)
            angles["arm_extension"] = MeasuredAngle(value: round(normalized), label: "Arm extension: \(Int(normalized))°", visible: true)
        } else {
            angles["arm_extension"] = MeasuredAngle(value: 0, label: "Arm extension: NOT_VISIBLE", visible: false)
        }

        return angles
    }

    private func computeAngle(a: JointData?, b: JointData?, c: JointData?) -> Double? {
        guard let a = a, let b = b, let c = c,
              a.confidence >= minConfidence, b.confidence >= minConfidence, c.confidence >= minConfidence
        else { return nil }

        let ba = (x: a.x - b.x, y: a.y - b.y)
        let bc = (x: c.x - b.x, y: c.y - b.y)
        let dot = ba.x * bc.x + ba.y * bc.y
        let magBA = hypot(ba.x, ba.y)
        let magBC = hypot(bc.x, bc.y)
        guard magBA > 0, magBC > 0 else { return nil }

        let cosAngle = max(-1, min(1, dot / (magBA * magBC)))
        return acos(cosAngle) * 180 / .pi
    }
}
```


## FILE: TennisIQ/Services/SubscriptionService.swift
```swift
import Foundation
import StoreKit

@MainActor
final class SubscriptionService: ObservableObject {
    @Published var currentTier: SubscriptionTier = .free
    @Published var freeAnalysesUsed: Int = 0
    @Published var availableProducts: [Product] = []
    @Published var isLoading = false

    private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await updateSubscriptionStatus() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIDs = [
                AppConstants.Subscription.monthlyProductID,
                AppConstants.Subscription.annualProductID,
            ]
            availableProducts = try await Product.products(for: Set(productIDs))
                .sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()

        case .pending:
            break
        case .userCancelled:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Check Entitlement

    func recordAnalysisUsed() {
        if currentTier == .free {
            freeAnalysesUsed += 1
            UserDefaults.standard.set(freeAnalysesUsed, forKey: "freeAnalysesUsed")
        }
    }

    var canAnalyze: Bool {
        currentTier != .free || freeAnalysesUsed < AppConstants.Analysis.freeSessionsAllowed
    }

    // MARK: - Private

    private func updateSubscriptionStatus() async {
        freeAnalysesUsed = UserDefaults.standard.integer(forKey: "freeAnalysesUsed")

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            if transaction.productID == AppConstants.Subscription.annualProductID {
                currentTier = .annual
                return
            } else if transaction.productID == AppConstants.Subscription.monthlyProductID {
                currentTier = .monthly
                return
            }
        }

        currentTier = .free
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                guard let _ = try? self.checkVerified(result) else { continue }
                await self.updateSubscriptionStatus()
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
```


## FILE: TennisIQ/Services/VoiceFeedbackService.swift
```swift
import Foundation
import AVFoundation

@MainActor
final class VoiceFeedbackService: NSObject, ObservableObject {
    @Published var isEnabled: Bool = true

    enum FeedbackIntensity: String, CaseIterable {
        case minimal
        case standard
        case detailed
    }

    enum Priority {
        case high
        case normal
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var pendingQueue: [(text: String, priority: Priority)] = []
    private var isSpeaking = false
    private var cooldownTask: Task<Void, Never>?
    private var cooldownInterval: TimeInterval
    private var rate: Float
    private var pitch: Float
    private var intensity: FeedbackIntensity

    init(
        rate: Float = 0.5,
        pitch: Float = 1.0,
        cooldown: TimeInterval = 3.0,
        intensity: FeedbackIntensity = .standard
    ) {
        self.rate = rate
        self.pitch = pitch
        self.cooldownInterval = cooldown
        self.intensity = intensity
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, priority: Priority = .normal) {
        guard isEnabled, !text.isEmpty else { return }

        switch priority {
        case .high:
            synthesizer.stopSpeaking(at: .immediate)
            pendingQueue.removeAll()
            cooldownTask?.cancel()
            cooldownTask = nil
            enqueueAndSpeak(text)
        case .normal:
            if isSpeaking {
                pendingQueue.append((text, priority))
            } else {
                enqueueAndSpeak(text)
            }
        }
    }

    private func enqueueAndSpeak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.05

        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        pendingQueue.removeAll()
        cooldownTask?.cancel()
        cooldownTask = nil
        isSpeaking = false
    }

    func configure(rate: Float? = nil, pitch: Float? = nil, cooldown: TimeInterval? = nil, intensity: FeedbackIntensity? = nil) {
        if let r = rate { self.rate = r }
        if let p = pitch { self.pitch = p }
        if let c = cooldown { self.cooldownInterval = c }
        if let i = intensity { self.intensity = i }
    }
}

extension VoiceFeedbackService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.handleDidFinish()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
        }
    }

    private func handleDidFinish() {
        isSpeaking = false
        startCooldown()
    }

    private func startCooldown() {
        cooldownTask?.cancel()
        cooldownTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(cooldownInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await processQueue()
        }
    }

    private func processQueue() {
        guard !isSpeaking, let next = pendingQueue.first else { return }
        pendingQueue.removeFirst()
        enqueueAndSpeak(next.text)
    }
}
```


## FILE: TennisIQ/Utilities/Color+Hex.swift
```swift
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```


## FILE: TennisIQ/Utilities/Constants.swift
```swift
import Foundation

enum AppConstants {
    static let appName = "TennisIQ"
    static let minimumIOSVersion = "17.0"
    static let minimumDeviceModel = "iPhone 12"

    static let privacyPolicyURL = URL(string: "https://tennisiq.com/privacy")!
    static let termsOfServiceURL = URL(string: "https://tennisiq.com/terms")!
    static let supportEmail = "support@tennisiq.com"
    static let appStoreID = "" // Set after App Store Connect setup

    enum Camera {
        static let defaultFPS: Int = 60
        static let processingFPS: Int = 15
        static let maxRecordingDuration: TimeInterval = 1800
        static let recommendedDistance = "10-15 feet away"
        static let recommendedHeight = "Waist height"
    }

    enum Analysis {
        static let maxKeyFrames: Int = 20
        static let poseConfidenceThreshold: Float = 0.3
        static let freeSessionsAllowed: Int = 3
    }

    enum API {
        static let baseURL = "https://api.tennisiq.com/api/v1"
        #if DEBUG
        static let debugBaseURL = "http://10.0.0.48:8000/api/v1"
        #endif
    }

    enum Supabase {
        static var projectURL: String {
            ProcessInfo.processInfo.environment["SUPABASE_URL"]
                ?? "https://ksfntpplbgtingcdizey.supabase.co"
        }
        static var anonKey: String {
            ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
                ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzZm50cHBsYmd0aW5nY2RpemV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE0MTU3MDUsImV4cCI6MjA4Njk5MTcwNX0.J5dXectt7PaB5cc5EEdwHOSbnr6G89tbY3_W1ywBgHE"
        }
        static let storageBucket = "session-frames"
    }

    enum Subscription {
        static let monthlyProductID = "tennisiq_monthly"
        static let annualProductID = "tennisiq_annual"
    }

    enum Feedback {
        static let minSessionsBeforePrompt = 2
        static let minSessionsBeforeRatingPrompt = 3
    }
}
```


## FILE: TennisIQ/ViewModels/AnalysisViewModel.swift
```swift
import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class AnalysisViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var analysisPhase: AnalysisPhase = .idle
    @Published var poseProgress: Double = 0
    @Published var error: String?

    let session: SessionModel
    private let poseService = PoseEstimationService()
    private let apiService = AnalysisAPIService()
    private var progressCancellable: AnyCancellable?

    enum AnalysisPhase: Equatable {
        case idle
        case extractingPoses
        case sendingToAPI
        case complete
        case failed(String)
    }

    init(session: SessionModel) {
        self.session = session
    }

    var needsAnalysis: Bool {
        session.status == .processing
    }

    func triggerAnalysis(context: ModelContext) async {
        guard session.status == .processing else { return }

        isLoading = true
        analysisPhase = .extractingPoses

        progressCancellable = poseService.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.poseProgress = value
            }

        do {
            let videoURL = resolveVideoURL()
            guard let url = videoURL else {
                throw AnalysisError.videoNotFound
            }

            let extraction = try await poseService.extractPoses(from: url)

            await MainActor.run {
                poseProgress = 1.0
                analysisPhase = .sendingToAPI
                session.status = .analyzing
                try? context.save()
            }

            let payload = SessionPosePayload(
                sessionID: session.id.uuidString,
                durationSeconds: session.durationSeconds,
                fps: AppConstants.Camera.processingFPS,
                frames: extraction.frames,
                keyFrameTimestamps: extraction.keyFrames.map(\.timestamp),
                skillLevel: UserDefaults.standard.string(forKey: "skillLevel") ?? "beginner",
                handedness: Handedness.current.rawValue,
                detectedStrokes: extraction.detectedStrokes
            )

            // Backend debug mode expects any non-empty bearer token.
            let storedToken = KeychainHelper.shared.read(key: "apple_id_token")?.trimmingCharacters(in: .whitespacesAndNewlines)
            let authToken = (storedToken?.isEmpty == false) ? storedToken! : "dev-token"

            let response = try await apiService.analyzeSession(
                posePayload: payload,
                keyFrameImages: extraction.keyFrames.map { (timestamp: $0.timestamp, image: $0.image) },
                authToken: authToken
            )

            applyResults(response, extractionFrames: extraction.frames, to: session, context: context)

            progressCancellable?.cancel()
            analysisPhase = .complete
            isLoading = false

        } catch {
            progressCancellable?.cancel()
            analysisPhase = .failed(error.localizedDescription)
            self.error = error.localizedDescription
            session.status = .failed
            try? context.save()
            isLoading = false
        }
    }

    private func resolveVideoURL() -> URL? {
        guard let filename = session.videoLocalURL else { return nil }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = documentsURL.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func applyResults(
        _ response: AnalysisResponse,
        extractionFrames: [FramePoseData],
        to session: SessionModel,
        context: ModelContext
    ) {
        session.overallGrade = response.sessionGrade
        session.topPriority = response.topPriority
        session.tacticalNotes = response.tacticalNotes
        session.poseFramesJSON = try? JSONEncoder().encode(extractionFrames)
        session.status = .ready

        for stroke in response.strokesDetected {
            let nearestFrame = nearestFrame(to: stroke.timestamp, from: extractionFrames)
            let model = StrokeAnalysisModel(
                strokeType: stroke.type,
                timestamp: stroke.timestamp,
                grade: stroke.grade
            )
            model.mechanicsJSON = try? JSONEncoder().encode(stroke.mechanics)
            model.overlayInstructionsJSON = try? JSONEncoder().encode(stroke.overlayInstructions)
            model.jointSnapshotJSON = try? JSONEncoder().encode(nearestFrame?.joints ?? [])
            model.gradingRationale = stroke.gradingRationale
            model.nextRepsPlan = stroke.nextRepsPlan
            model.verifiedSourcesJSON = try? JSONEncoder().encode(stroke.verifiedSources ?? [])
            model.phaseBreakdownJSON = try? JSONEncoder().encode(stroke.phaseBreakdown)
            model.analysisCategoriesJSON = try? JSONEncoder().encode(stroke.analysisCategories)
            model.session = session
            context.insert(model)
        }

        try? context.save()
    }

    private func nearestFrame(to timestamp: Double, from frames: [FramePoseData]) -> FramePoseData? {
        guard !frames.isEmpty else { return nil }
        return frames.min { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) }
    }

    enum AnalysisError: LocalizedError {
        case videoNotFound

        var errorDescription: String? {
            switch self {
            case .videoNotFound: return "Recording video file not found."
            }
        }
    }
}
```


## FILE: TennisIQ/ViewModels/RecordViewModel.swift
```swift
import Foundation
import SwiftUI
import SwiftData
import AVFoundation
import Combine

@MainActor
final class RecordViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isSessionReady = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var error: CameraService.CameraError?
    @Published var lastSavedSession: SessionModel?
    @Published var showSessionSaved = false

    let cameraService = CameraService()
    private var timerCancellable: AnyCancellable?
    private var recordingStartTime: Date?
    private var modelContext: ModelContext?

    var formattedDuration: String {
        let total = Int(recordingDuration)
        let minutes = total / 60
        let seconds = total % 60
        let tenths = Int((recordingDuration - Double(total)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }

    func setup() async {
        do {
            try await cameraService.setupSession()
            isSessionReady = true
        } catch let err as CameraService.CameraError {
            error = err
        } catch {
            self.error = .setupFailed(error.localizedDescription)
        }
    }

    func startRecording(context: ModelContext) {
        modelContext = context
        recordingStartTime = Date()
        recordingDuration = 0

        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }

        cameraService.startRecording { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let url):
                    self.saveSession(videoURL: url)
                case .failure(let err):
                    self.error = err
                }
            }
        }
        isRecording = true
    }

    func stopRecording() {
        cameraService.stopRecording()
        isRecording = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    func teardown() {
        stopRecording()
        cameraService.teardown()
        isSessionReady = false
    }

    func dismissSavedOverlay() {
        showSessionSaved = false
        lastSavedSession = nil
    }

    private func saveSession(videoURL: URL) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = "session_\(UUID().uuidString).mov"
        let destinationURL = documentsURL.appendingPathComponent(filename)

        do {
            try FileManager.default.moveItem(at: videoURL, to: destinationURL)

            let duration = Int(recordingDuration)
            let session = SessionModel(
                recordedAt: recordingStartTime ?? Date(),
                durationSeconds: duration,
                status: .processing,
                videoLocalURL: filename
            )
            modelContext?.insert(session)
            try? modelContext?.save()

            lastSavedSession = session
            showSessionSaved = true
        } catch {
            self.error = .recordingFailed("Failed to save video: \(error.localizedDescription)")
        }
    }
}
```


## FILE: TennisIQ/Views/Components/FeedbackPromptView.swift
```swift
import SwiftUI

struct FeedbackPromptView: View {
    @Binding var isPresented: Bool
    @State private var selectedRating: Int = 0
    @State private var feedbackText = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false

    private let theme = DesignSystem.current
    let onSubmit: (Int, String) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: Spacing.lg) {
                header
                ratingStars
                feedbackField
                actionButtons
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(theme.surfacePrimary)
            )
            .padding(.horizontal, Spacing.lg)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        }
    }

    private var header: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(theme.accent)

            Text(didSubmit ? "Thank You!" : "How was your analysis?")
                .font(AppFont.display(size: 20))
                .foregroundStyle(theme.textPrimary)

            Text(didSubmit
                 ? "Your feedback helps us improve."
                 : "Your feedback shapes how we build this app.")
                .font(AppFont.body(size: 14))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var ratingStars: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(1...5, id: \.self) { star in
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedRating = star } }) {
                    Image(systemName: star <= selectedRating ? "star.fill" : "star")
                        .font(.system(size: 28))
                        .foregroundStyle(star <= selectedRating ? theme.accent : theme.textTertiary)
                }
            }
        }
        .opacity(didSubmit ? 0.5 : 1)
        .disabled(didSubmit)
    }

    private var feedbackField: some View {
        Group {
            if !didSubmit {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("What would make this better?")
                        .font(AppFont.body(size: 12, weight: .medium))
                        .foregroundStyle(theme.textTertiary)

                    TextField("Optional feedback...", text: $feedbackText, axis: .vertical)
                        .font(AppFont.body(size: 14))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(3...5)
                        .padding(Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(theme.surfaceSecondary)
                        )
                }
            }
        }
    }

    private var actionButtons: some View {
        Group {
            if didSubmit {
                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(AppFont.body(size: 16, weight: .semibold))
                        .foregroundStyle(theme.textOnAccent)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .fill(theme.accent)
                        )
                }
            } else {
                VStack(spacing: Spacing.xs) {
                    Button(action: submit) {
                        Group {
                            if isSubmitting {
                                ProgressView()
                                    .tint(theme.textOnAccent)
                            } else {
                                Text("Submit Feedback")
                                    .font(AppFont.body(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundStyle(theme.textOnAccent)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .fill(selectedRating > 0 ? theme.accent : theme.textTertiary)
                        )
                    }
                    .disabled(selectedRating == 0 || isSubmitting)

                    Button("Not Now") { dismiss() }
                        .font(AppFont.body(size: 14))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
    }

    private func submit() {
        guard selectedRating > 0 else { return }
        isSubmitting = true

        AnalyticsService.shared.trackEvent(.feedbackSubmitted(rating: selectedRating))
        AnalyticsService.shared.markFeedbackGiven()
        onSubmit(selectedRating, feedbackText)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSubmitting = false
            withAnimation { didSubmit = true }
        }
    }

    private func dismiss() {
        if !didSubmit {
            AnalyticsService.shared.trackEvent(.feedbackPromptDismissed)
        }
        isPresented = false
    }
}
```


## FILE: TennisIQ/Views/Components/PhaseDetailCard.swift
```swift
import SwiftUI

struct PhaseDetailCard: View {
    let phase: SwingPhase
    let detail: PhaseDetail?

    @State private var isExpanded = true
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded, let d = detail {
                expandedContent(detail: d)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(theme.surfaceSecondary, lineWidth: 1)
        )
    }

    private var header: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: phase.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36)
                    .background(theme.accentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(phase.displayName)
                        .font(AppFont.body(size: 15, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    if let d = detail {
                        Text(String(format: "@ %.1fs", d.timestamp))
                            .font(AppFont.mono(size: 12))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                Spacer()

                if let d = detail {
                    ZStack {
                        Circle()
                            .stroke(theme.surfaceSecondary, lineWidth: 3)
                            .frame(width: 40, height: 40)
                        Circle()
                            .trim(from: 0, to: CGFloat(d.score) / 10)
                            .stroke(scoreColor(d.score), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                        Text("\(d.score)")
                            .font(AppFont.mono(size: 12, weight: .bold))
                            .foregroundStyle(theme.textPrimary)
                    }
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(Spacing.md)
        }
        .buttonStyle(.plain)
    }

    private func expandedContent(detail: PhaseDetail) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Divider().foregroundStyle(theme.surfaceSecondary)

            if !detail.keyAngles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(detail.keyAngles, id: \.self) { angle in
                            Text(angle)
                                .font(AppFont.mono(size: 11))
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xxs)
                                .background(Capsule().fill(theme.accentMuted))
                        }
                    }
                }
            }

            if !detail.note.isEmpty {
                Text(detail.note)
                    .font(AppFont.body(size: 13))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
            }

            if let cue = detail.improveCue, !cue.isEmpty {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Rectangle()
                        .fill(theme.accent)
                        .frame(width: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Coaching Cue")
                            .font(AppFont.body(size: 11, weight: .semibold))
                            .foregroundStyle(theme.accent)
                        Text(cue)
                            .font(AppFont.body(size: 13))
                            .foregroundStyle(theme.textPrimary)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(theme.accentMuted.opacity(0.5))
                )
            }

            if let drill = detail.drill, !drill.isEmpty {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.accentSecondary)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Practice Drill")
                            .font(AppFont.body(size: 11, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                        Text(drill)
                            .font(AppFont.body(size: 13))
                            .foregroundStyle(theme.textPrimary)
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(theme.surfaceSecondary)
                )
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 8...10: return theme.success
        case 5...7: return theme.accent
        case 3...4: return theme.warning
        default: return theme.error
        }
    }
}
```


## FILE: TennisIQ/Views/Components/PhaseTimelineView.swift
```swift
import SwiftUI

struct PhaseTimelineView: View {
    let breakdown: PhaseBreakdown
    @Binding var selectedPhase: SwingPhase?
    let onPhaseSelected: (SwingPhase) -> Void

    private let theme = DesignSystem.current

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(breakdown.allPhases.enumerated()), id: \.offset) { index, item in
                    let (phase, detail) = item
                    phaseNode(phase: phase, detail: detail)
                    if index < breakdown.allPhases.count - 1 {
                        connectingLine(status: detail?.status ?? .warning)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func phaseNode(phase: SwingPhase, detail: PhaseDetail?) -> some View {
        let isSelected = selectedPhase == phase
        let score = detail?.score ?? 0
        let status = detail?.status ?? .warning

        return Button(action: {
            selectedPhase = phase
            onPhaseSelected(phase)
        }) {
            VStack(spacing: Spacing.xxs) {
                ZStack {
                    Circle()
                        .fill(zoneColor(status))
                        .frame(width: 36, height: 36)

                    Text("\(score)")
                        .font(AppFont.mono(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? theme.accent : .clear, lineWidth: 2.5)
                        .frame(width: 42, height: 42)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)

                Text(phase.displayName)
                    .font(AppFont.body(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 52)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
    }

    private func connectingLine(status: ZoneStatus) -> some View {
        Rectangle()
            .fill(zoneColor(status).opacity(0.5))
            .frame(width: 16, height: 2)
    }

    private func zoneColor(_ status: ZoneStatus) -> Color {
        switch status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }
}
```


## FILE: TennisIQ/Views/Components/ProComparisonView.swift
```swift
import SwiftUI

struct ProComparisonView: View {
    let userJoints: [JointData]
    let proName: String
    let strokeType: StrokeType
    let alignmentScores: [AlignmentScore]
    let windowBadges: [WindowBadge]

    private let theme = DesignSystem.current
    private let proService = ProComparisonService()

    private let bones: [(String, String)] = [
        ("left_shoulder", "right_shoulder"),
        ("left_shoulder", "left_elbow"),
        ("left_elbow", "left_wrist"),
        ("right_shoulder", "right_elbow"),
        ("right_elbow", "right_wrist"),
        ("left_shoulder", "left_hip"),
        ("right_shoulder", "right_hip"),
        ("left_hip", "right_hip"),
        ("left_hip", "left_knee"),
        ("left_knee", "left_ankle"),
        ("right_hip", "right_knee"),
        ("right_knee", "right_ankle")
    ]

    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack(alignment: .center) {
                HStack(spacing: 0) {
                    skeletonHalf(
                        joints: userJoints,
                        label: "You",
                        color: Color(hex: "4A90D9")
                    )
                    Rectangle()
                        .fill(theme.surfaceSecondary)
                        .frame(width: 2)
                    skeletonHalf(
                        joints: proService.getProPoseData(proName: proName, stroke: strokeType, phase: .contactPoint) ?? [],
                        label: proName,
                        color: theme.accentSecondary
                    )
                }
                .frame(height: 220)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(Color(hex: "1A2332"))
                )
                .overlay(alignment: .topTrailing) {
                    if !windowBadges.isEmpty {
                        HStack(spacing: Spacing.xxs) {
                            ForEach(windowBadges) { badge in
                                Text(badge.label)
                                    .font(AppFont.body(size: 10, weight: .semibold))
                                    .foregroundStyle(zoneColor(badge.status))
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xxs)
                                    .background(
                                        Capsule().fill(theme.surfaceElevated).opacity(0.95)
                                    )
                            }
                        }
                        .padding(Spacing.sm)
                    }
                }
            }

            VStack(spacing: Spacing.xs) {
                ForEach(alignmentScores) { score in
                    alignmentRow(score)
                }
            }
        }
    }

    private func skeletonHalf(joints: [JointData], label: String, color: Color) -> some View {
        let map = Dictionary(uniqueKeysWithValues: joints.map { ($0.name, $0) })

        return VStack(spacing: Spacing.xs) {
            Text(label)
                .font(AppFont.body(size: 12, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            Canvas { context, size in
                let w = size.width
                let h = size.height - 24
                for (a, b) in bones {
                    guard let ja = map[a], let jb = map[b] else { continue }
                    let ptA = toView(ja, width: w, height: h)
                    let ptB = toView(jb, width: w, height: h)
                    var p = Path()
                    p.move(to: ptA)
                    p.addLine(to: ptB)
                    context.stroke(
                        p,
                        with: .color(color.opacity(0.9)),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.sm)
    }

    private func toView(_ joint: JointData, width: CGFloat, height: CGFloat) -> CGPoint {
        let x = joint.x * width
        let y = (1 - joint.y) * height
        return CGPoint(x: x, y: y)
    }

    private func alignmentRow(_ score: AlignmentScore) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(score.bodyGroup)
                .font(AppFont.body(size: 13, weight: .medium))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 100, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(theme.surfaceSecondary)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(zoneColor(score.status))
                        .frame(width: geo.size.width * CGFloat(score.percentage) / 100, height: 8)
                }
            }
            .frame(height: 8)

            Text("\(score.percentage)%")
                .font(AppFont.mono(size: 12, weight: .bold))
                .foregroundStyle(zoneColor(score.status))
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func zoneColor(_ status: ZoneStatus) -> Color {
        switch status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }
}
```


## FILE: TennisIQ/Views/Components/SwingPathOverlayView.swift
```swift
import SwiftUI

struct SwingPathOverlayView: View {
    let wristPoints: [CGPoint]
    let videoNaturalSize: CGSize

    private let theme = DesignSystem.current
    private let dotSpacing: CGFloat = 8
    private let dotSize: CGFloat = 6
    private let glowRadius: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let crop = aspectFillCrop(videoSize: videoNaturalSize, viewSize: size)
                let screenPoints = wristPoints.map { toScreen($0, crop: crop) }

                guard screenPoints.count >= 2 else { return }

                let evenPoints = resamplePath(screenPoints, spacing: dotSpacing)
                let totalDots = evenPoints.count

                for (i, pt) in evenPoints.enumerated() {
                    let progress = totalDots > 1 ? Double(i) / Double(totalDots - 1) : 1.0
                    let opacity = 0.15 + 0.85 * progress
                    let radius = (dotSize * 0.4) + (dotSize * 0.6 * progress)

                    let glowRect = CGRect(
                        x: pt.x - radius - glowRadius,
                        y: pt.y - radius - glowRadius,
                        width: (radius + glowRadius) * 2,
                        height: (radius + glowRadius) * 2
                    )
                    context.fill(
                        Circle().path(in: glowRect),
                        with: .color(theme.success.opacity(opacity * 0.25))
                    )

                    let dotRect = CGRect(
                        x: pt.x - radius,
                        y: pt.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(
                        Circle().path(in: dotRect),
                        with: .color(theme.success.opacity(opacity))
                    )
                }

                if let last = evenPoints.last {
                    let headRadius = dotSize * 0.9
                    let headRect = CGRect(
                        x: last.x - headRadius,
                        y: last.y - headRadius,
                        width: headRadius * 2,
                        height: headRadius * 2
                    )
                    context.fill(Circle().path(in: headRect), with: .color(.white))

                    let outerRect = CGRect(
                        x: last.x - headRadius - 3,
                        y: last.y - headRadius - 3,
                        width: (headRadius + 3) * 2,
                        height: (headRadius + 3) * 2
                    )
                    context.stroke(
                        Circle().path(in: outerRect),
                        with: .color(theme.success),
                        lineWidth: 2
                    )
                }
            }
        }
    }

    private func resamplePath(_ points: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        var resampled: [CGPoint] = [points[0]]
        var accumulated: CGFloat = 0

        for i in 1..<points.count {
            let dx = points[i].x - points[i - 1].x
            let dy = points[i].y - points[i - 1].y
            let segmentLength = hypot(dx, dy)

            guard segmentLength > 0 else { continue }

            var remaining = segmentLength
            var fromPoint = points[i - 1]
            let dirX = dx / segmentLength
            let dirY = dy / segmentLength

            while accumulated + remaining >= spacing {
                let step = spacing - accumulated
                let newPoint = CGPoint(
                    x: fromPoint.x + dirX * step,
                    y: fromPoint.y + dirY * step
                )
                resampled.append(newPoint)
                fromPoint = newPoint
                remaining -= step
                accumulated = 0
            }
            accumulated += remaining
        }

        return resampled
    }

    private struct CropInfo {
        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
    }

    private func aspectFillCrop(videoSize: CGSize, viewSize: CGSize) -> CropInfo {
        guard videoSize.width > 0, videoSize.height > 0 else {
            return CropInfo(scale: 1, offsetX: 0, offsetY: 0)
        }
        let videoAspect = videoSize.width / videoSize.height
        let viewAspect = viewSize.width / viewSize.height

        if videoAspect < viewAspect {
            let scale = viewSize.width / videoSize.width
            return CropInfo(scale: scale, offsetX: 0, offsetY: (viewSize.height - videoSize.height * scale) / 2)
        } else {
            let scale = viewSize.height / videoSize.height
            return CropInfo(scale: scale, offsetX: (viewSize.width - videoSize.width * scale) / 2, offsetY: 0)
        }
    }

    private func toScreen(_ pt: CGPoint, crop: CropInfo) -> CGPoint {
        let videoX = pt.y * videoNaturalSize.width
        let videoY = pt.x * videoNaturalSize.height
        return CGPoint(
            x: videoX * crop.scale + crop.offsetX,
            y: videoY * crop.scale + crop.offsetY
        )
    }
}
```


## FILE: TennisIQ/Views/Components/ZoneIndicator.swift
```swift
import SwiftUI

struct ZoneIndicator: View {
    let status: ZoneStatus
    var style: Style = .badge

    enum Style {
        case badge
        case dot
    }

    private let theme = DesignSystem.current

    var body: some View {
        switch style {
        case .badge:
            Text(status.displayLabel)
                .font(AppFont.body(size: 12, weight: .semibold))
                .foregroundStyle(zoneColor)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(Capsule().fill(zoneColor.opacity(0.15)))
        case .dot:
            Circle()
                .fill(zoneColor)
                .frame(width: 8, height: 8)
        }
    }

    private var zoneColor: Color {
        switch status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }
}
```


## FILE: TennisIQ/Views/Onboarding/OnboardingView.swift
```swift
import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    let theme = DesignSystem.current

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "video.fill",
            title: "Record Your Session",
            description: "Set up your iPhone on a tripod or lean it against the fence. Hit record and play your game.",
            accentColorKeyPath: \.accent
        ),
        OnboardingPage(
            icon: "figure.tennis",
            title: "AI Analyzes Your Form",
            description: "Our AI tracks your body movement, identifies each stroke, and evaluates your mechanics against professional technique.",
            accentColorKeyPath: \.accentSecondary
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Get Better, Fast",
            description: "Receive visual coaching overlays on your video, track your progress over time, and know exactly what to practice.",
            accentColorKeyPath: \.accent
        ),
    ]

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomControls
            }
        }
    }

    // MARK: - Page Content

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.08))
                    .frame(width: 160, height: 160)

                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(theme.accent)
            }

            VStack(spacing: Spacing.md) {
                Text(page.title)
                    .font(AppFont.display(size: 28))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(AppFont.body(size: 16))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Spacing.xl)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.xs) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? theme.accent : theme.textTertiary.opacity(0.3))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.25), value: currentPage)
                }
            }

            Button(action: advance) {
                Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")
                    .font(AppFont.body(size: 17, weight: .semibold))
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .padding(.horizontal, Spacing.lg)

            if currentPage < pages.count - 1 {
                Button("Skip") {
                    hasCompletedOnboarding = true
                }
                .font(AppFont.body(size: 15))
                .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.bottom, Spacing.xxl)
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation { currentPage += 1 }
        } else {
            hasCompletedOnboarding = true
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let accentColorKeyPath: KeyPath<any AppTheme, Color>
}
```


## FILE: TennisIQ/Views/Profile/ProfileView.swift
```swift
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @AppStorage("selectedTheme") private var selectedTheme = "Court Vision"
    @State private var selectedSkillLevel: SkillLevel = .beginner
    @State private var selectedHandedness: Handedness = Handedness.current
    let theme = DesignSystem.current

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        profileHeader
                        subscriptionCard
                        settingsSection
                        handednessSection
                        themeSection
                        legalSection
                        signOutButton
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle("Profile")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.1))
                    .frame(width: 80, height: 80)

                Text(initials)
                    .font(AppFont.display(size: 28))
                    .foregroundStyle(theme.accent)
            }

            Text(authService.displayName ?? "Tennis Player")
                .font(AppFont.display(size: 20))
                .foregroundStyle(theme.textPrimary)

            Text(selectedSkillLevel.displayName)
                .font(AppFont.body(size: 14))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    // MARK: - Subscription Card

    private var subscriptionCard: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Current Plan")
                        .font(AppFont.body(size: 13))
                        .foregroundStyle(theme.textSecondary)

                    Text(subscriptionService.currentTier.displayName)
                        .font(AppFont.display(size: 18))
                        .foregroundStyle(theme.textPrimary)
                }

                Spacer()

                if subscriptionService.currentTier == .free {
                    Button(action: {}) {
                        Text("Upgrade")
                            .font(AppFont.body(size: 14, weight: .semibold))
                            .foregroundStyle(theme.textOnAccent)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(theme.accent)
                            .clipShape(Capsule())
                    }
                }
            }

            if subscriptionService.currentTier == .free {
                let remaining = AppConstants.Analysis.freeSessionsAllowed - subscriptionService.freeAnalysesUsed
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(theme.accent)
                        .font(.system(size: 14))

                    Text("\(remaining) free analyses remaining")
                        .font(AppFont.body(size: 13))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SKILL LEVEL")
                .font(AppFont.body(size: 12, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    Button(action: { selectedSkillLevel = level }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.displayName)
                                    .font(AppFont.body(size: 15, weight: .medium))
                                    .foregroundStyle(theme.textPrimary)

                                Text(level.description)
                                    .font(AppFont.body(size: 12))
                                    .foregroundStyle(theme.textTertiary)
                            }

                            Spacer()

                            if selectedSkillLevel == level {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.accent)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .padding(Spacing.md)
                    }
                    .buttonStyle(.plain)

                    if level != SkillLevel.allCases.last {
                        Divider()
                            .background(theme.surfaceSecondary)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.surfacePrimary)
            )
        }
    }

    // MARK: - Handedness

    private var handednessSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("DOMINANT HAND")
                .font(AppFont.body(size: 12, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                ForEach(Handedness.allCases, id: \.self) { hand in
                    Button(action: {
                        selectedHandedness = hand
                        Handedness.save(hand)
                    }) {
                        HStack {
                            Image(systemName: hand == .left ? "hand.raised.fingers.spread" : "hand.raised.fingers.spread")
                                .font(.system(size: 16))
                                .foregroundStyle(theme.accent)
                                .scaleEffect(x: hand == .left ? -1 : 1, y: 1)

                            Text("\(hand.displayName)-Handed")
                                .font(AppFont.body(size: 15, weight: .medium))
                                .foregroundStyle(theme.textPrimary)

                            Spacer()

                            if selectedHandedness == hand {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.accent)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .padding(Spacing.md)
                    }
                    .buttonStyle(.plain)

                    if hand != Handedness.allCases.last {
                        Divider().background(theme.surfaceSecondary)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.surfacePrimary)
            )
        }
    }

    // MARK: - Theme Selector

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("DESIGN THEME")
                .font(AppFont.body(size: 12, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                themeOption("Court Vision", theme: CourtVisionTheme())
                Divider().background(theme.surfaceSecondary)
                themeOption("Grand Slam", theme: GrandSlamTheme())
                Divider().background(theme.surfaceSecondary)
                themeOption("Rally", theme: RallyTheme())
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.surfacePrimary)
            )
        }
    }

    private func themeOption(_ name: String, theme appTheme: AppTheme) -> some View {
        Button(action: {
            selectedTheme = name
            DesignSystem.shared.setTheme(appTheme)
        }) {
            HStack(spacing: Spacing.sm) {
                HStack(spacing: 4) {
                    Circle().fill(appTheme.accent).frame(width: 16, height: 16)
                    Circle().fill(appTheme.accentSecondary).frame(width: 16, height: 16)
                    Circle().fill(appTheme.background).frame(width: 16, height: 16)
                        .overlay(Circle().stroke(theme.textTertiary.opacity(0.3), lineWidth: 1))
                }

                Text(name)
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                if selectedTheme == name {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .padding(Spacing.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("LEGAL")
                .font(AppFont.body(size: 12, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .padding(.leading, Spacing.xs)

            VStack(spacing: 0) {
                legalLink("Privacy Policy", url: AppConstants.privacyPolicyURL)
                Divider().background(theme.surfaceSecondary)
                legalLink("Terms of Service", url: AppConstants.termsOfServiceURL)
                Divider().background(theme.surfaceSecondary)
                legalLink("Contact Support", url: URL(string: "mailto:\(AppConstants.supportEmail)")!)
                Divider().background(theme.surfaceSecondary)
                legalLink("Chat with the Founder", url: URL(string: "mailto:\(AppConstants.supportEmail)?subject=App%20Feedback")!)
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.surfacePrimary)
            )
        }
    }

    private func legalLink(_ title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(title)
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Sign Out

    private var signOutButton: some View {
        Button(action: { authService.signOut() }) {
            Text("Sign Out")
                .font(AppFont.body(size: 15, weight: .medium))
                .foregroundStyle(theme.error)
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(theme.surfacePrimary)
                )
        }
    }

    private var initials: String {
        let name = authService.displayName ?? "TP"
        let parts = name.split(separator: " ")
        let first = parts.first.map { String($0.prefix(1)).uppercased() } ?? "T"
        let last = parts.count > 1 ? String(parts.last!.prefix(1)).uppercased() : "P"
        return first + last
    }
}
```


## FILE: TennisIQ/Views/Progress/ProgressDashboardView.swift
```swift
import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    @Query(sort: \ProgressSnapshotModel.snapshotDate, order: .reverse)
    private var snapshots: [ProgressSnapshotModel]

    @Query(
        filter: #Predicate<SessionModel> { $0.status.rawValue == "ready" },
        sort: \SessionModel.recordedAt,
        order: .reverse
    )
    private var recentSessions: [SessionModel]

    let theme = DesignSystem.current

    private var latest: ProgressSnapshotModel? { snapshots.first }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                if snapshots.isEmpty {
                    emptyProgressState
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.md) {
                            overallScoreCard
                            strokeBreakdownGrid
                            weeklyFocusCard
                            progressChart
                            sessionStreakCard
                        }
                        .padding(Spacing.md)
                        .padding(.bottom, Spacing.xxl)
                    }
                }
            }
            .navigationTitle("Progress")
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }

    // MARK: - Overall Score

    private var overallScoreCard: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .stroke(theme.surfaceSecondary, lineWidth: 10)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: (latest?.overallScore ?? 0) / 100)
                    .stroke(
                        theme.accent,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(latest?.overallScore ?? 0))")
                        .font(AppFont.display(size: 40))
                        .foregroundStyle(theme.textPrimary)

                    Text("Overall")
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            if let trend = latest?.trendingDirection {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: trend.icon)
                        .font(.system(size: 14, weight: .bold))

                    Text(trend.rawValue.capitalized)
                        .font(AppFont.body(size: 14, weight: .medium))
                }
                .foregroundStyle(trendColor(trend))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(theme.surfacePrimary)
        )
    }

    // MARK: - Stroke Breakdown Grid

    private var strokeBreakdownGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: Spacing.sm),
            GridItem(.flexible(), spacing: Spacing.sm),
        ], spacing: Spacing.sm) {
            ForEach(StrokeType.allCases.filter { $0 != .unknown }, id: \.self) { stroke in
                strokeGauge(stroke)
            }
        }
    }

    private func strokeGauge(_ strokeType: StrokeType) -> some View {
        let score = latest?.score(for: strokeType) ?? 0

        return VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(theme.surfaceSecondary, lineWidth: 6)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(
                        strokeTypeColor(strokeType),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(score))")
                    .font(AppFont.mono(size: 18, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
            }

            VStack(spacing: 2) {
                Text(strokeType.displayName)
                    .font(AppFont.body(size: 13, weight: .medium))
                    .foregroundStyle(theme.textPrimary)

                Image(systemName: strokeType.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    // MARK: - Weekly Focus

    private var weeklyFocusCard: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "target")
                .font(.system(size: 20))
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("This Week's Focus")
                    .font(AppFont.body(size: 12))
                    .foregroundStyle(theme.textTertiary)

                Text(weeklyFocusText)
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.accentMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(theme.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Progress Chart

    private var progressChart: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SCORE OVER TIME")
                .font(AppFont.body(size: 11, weight: .semibold))
                .foregroundStyle(theme.textTertiary)

            if #available(iOS 16.0, *) {
                ProgressChartView(snapshots: Array(snapshots.prefix(30).reversed()))
                    .frame(height: 160)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    // MARK: - Session Streak

    private var sessionStreakCard: some View {
        let thisWeek = recentSessions.filter {
            Calendar.current.isDate($0.recordedAt, equalTo: Date(), toGranularity: .weekOfYear)
        }.count

        let thisMonth = recentSessions.filter {
            Calendar.current.isDate($0.recordedAt, equalTo: Date(), toGranularity: .month)
        }.count

        return HStack(spacing: Spacing.lg) {
            streakMetric(value: thisWeek, label: "This Week", icon: "flame.fill")
            Divider().frame(height: 40).background(theme.surfaceSecondary)
            streakMetric(value: thisMonth, label: "This Month", icon: "calendar")
            Divider().frame(height: 40).background(theme.surfaceSecondary)
            streakMetric(value: snapshots.count, label: "Total", icon: "figure.tennis")
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    private func streakMetric(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(theme.accent)

            Text("\(value)")
                .font(AppFont.display(size: 22))
                .foregroundStyle(theme.textPrimary)

            Text(label)
                .font(AppFont.body(size: 11))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyProgressState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(theme.textTertiary)

            VStack(spacing: Spacing.xs) {
                Text("No Progress Yet")
                    .font(AppFont.display(size: 22))
                    .foregroundStyle(theme.textPrimary)

                Text("Complete your first analysis\nto start tracking progress")
                    .font(AppFont.body(size: 15))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Helpers

    private var weeklyFocusText: String {
        guard let snap = latest else { return "Record a session to get started" }
        let scores: [(StrokeType, Double)] = [
            (.forehand, snap.forehandScore),
            (.backhand, snap.backhandScore),
            (.serve, snap.serveScore),
            (.volley, snap.volleyScore),
        ]
        let weakest = scores.min(by: { $0.1 < $1.1 })
        return "Work on your \(weakest?.0.displayName.lowercased() ?? "strokes")"
    }

    private func trendColor(_ trend: TrendDirection) -> Color {
        switch trend {
        case .improving: return theme.success
        case .stable: return theme.accentSecondary
        case .declining: return theme.error
        }
    }

    private func strokeTypeColor(_ type: StrokeType) -> Color {
        switch type {
        case .forehand: return theme.accent
        case .backhand: return theme.accentSecondary
        case .serve: return theme.success
        case .volley: return theme.warning
        case .unknown: return theme.textTertiary
        }
    }
}

// MARK: - Simple Line Chart (iOS 16+)

@available(iOS 16.0, *)
struct ProgressChartView: View {
    let snapshots: [ProgressSnapshotModel]
    let theme = DesignSystem.current

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            let scores = snapshots.map(\.overallScore)
            let maxScore = max(scores.max() ?? 100, 100)
            let minScore = max((scores.min() ?? 0) - 10, 0)
            let range = max(maxScore - minScore, 1)

            ZStack {
                // Grid lines
                ForEach([0.25, 0.5, 0.75], id: \.self) { fraction in
                    Path { path in
                        let y = height * (1 - fraction)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(theme.surfaceSecondary, lineWidth: 0.5)
                }

                if snapshots.count >= 2 {
                    // Gradient fill
                    Path { path in
                        for (i, snap) in snapshots.enumerated() {
                            let x = width * CGFloat(i) / CGFloat(snapshots.count - 1)
                            let y = height * (1 - (snap.overallScore - minScore) / range)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [theme.accent.opacity(0.2), theme.accent.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line
                    Path { path in
                        for (i, snap) in snapshots.enumerated() {
                            let x = width * CGFloat(i) / CGFloat(snapshots.count - 1)
                            let y = height * (1 - (snap.overallScore - minScore) / range)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    // Latest point dot
                    if let last = snapshots.last {
                        let x = width
                        let y = height * (1 - (last.overallScore - minScore) / range)
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }
}
```


## FILE: TennisIQ/Views/Record/LiveFeedbackOverlayView.swift
```swift
import SwiftUI

struct LiveFeedbackOverlayView: View {
    let isActive: Bool
    let currentPhase: SwingPhase?
    let latestFeedback: LiveFeedbackEvent?
    let formGrade: String?

    private let theme = DesignSystem.current

    var body: some View {
        ZStack {
            if isActive {
                liveIndicator
                formQualityRing
                phasePips
            }

            if let feedback = latestFeedback, isActive {
                floatingCue(feedback)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isActive)
        .animation(.spring(response: 0.4), value: latestFeedback?.id)
    }

    private var liveIndicator: some View {
        HStack(spacing: Spacing.xxs) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
                .opacity(pulseOpacity)

            Text("LIVE")
                .font(AppFont.body(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs + 2)
        .background(.red.opacity(0.85))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Spacing.sm)
    }

    @State private var pulseOpacity: Double = 1.0

    private var formQualityRing: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(gradeColor.opacity(0.3), lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .stroke(gradeColor, lineWidth: 3)
                    .frame(width: 40, height: 40)

                Text(formGrade ?? "--")
                    .font(AppFont.display(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("FORM")
                .font(AppFont.body(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(Spacing.sm)
    }

    private func floatingCue(_ event: LiveFeedbackEvent) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 11, weight: .semibold))

            Text("\"\(event.cueText)\"")
                .font(AppFont.body(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(statusColor(event.severity).opacity(0.85))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 56)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var phasePips: some View {
        HStack(spacing: 4) {
            ForEach(SwingPhase.allCases, id: \.self) { phase in
                Circle()
                    .fill(pipColor(for: phase))
                    .frame(width: phase == currentPhase ? 10 : 8, height: phase == currentPhase ? 10 : 8)
                    .scaleEffect(phase == currentPhase ? 1.3 : 1.0)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs + 2)
        .background(.black.opacity(0.5))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, Spacing.sm)
    }

    private func pipColor(for phase: SwingPhase) -> Color {
        guard let current = currentPhase else { return .white.opacity(0.2) }
        if phase == current { return theme.accent }
        if phase.rawValue < current.rawValue { return theme.success }
        return .white.opacity(0.2)
    }

    private var gradeColor: Color {
        guard let grade = formGrade else { return .white.opacity(0.5) }
        if grade.hasPrefix("A") { return theme.success }
        if grade.hasPrefix("B") { return theme.success }
        if grade.hasPrefix("C") { return theme.warning }
        return theme.error
    }

    private func statusColor(_ status: ZoneStatus) -> Color {
        switch status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }
}
```


## FILE: TennisIQ/Views/Record/RecordView.swift
```swift
import SwiftUI
import AVFoundation

struct RecordView: View {
    @StateObject private var viewModel = RecordViewModel()
    @StateObject private var liveAnalyzer = LiveSwingAnalyzer()
    @StateObject private var voiceFeedback = VoiceFeedbackService()
    @State private var liveModeEnabled = false
    @Environment(\.modelContext) private var modelContext
    let theme = DesignSystem.current
    var switchToSessions: () -> Void

    var body: some View {
        ZStack {
            if viewModel.showSessionSaved {
                sessionSavedScreen
            } else {
                cameraScreen
            }
        }
        .task {
            await viewModel.setup()
        }
        .onDisappear {
            viewModel.teardown()
        }
        .alert(
            "Camera Error",
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )
        ) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
    }

    // MARK: - Camera Screen

    private var cameraScreen: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if viewModel.isSessionReady {
                CameraPreviewRepresentable(previewLayer: viewModel.cameraService.previewLayer)
                    .ignoresSafeArea()
                    .overlay {
                        if viewModel.isRecording {
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(theme.accent, lineWidth: 3)
                                .ignoresSafeArea()
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.isRecording)
                        }
                    }
            } else {
                VStack(spacing: Spacing.lg) {
                    ProgressView()
                        .tint(theme.accent)
                        .scaleEffect(1.2)
                    Text("Setting up camera...")
                        .font(AppFont.body(size: 16))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            if liveModeEnabled && viewModel.isRecording {
                LiveFeedbackOverlayView(
                    isActive: liveModeEnabled && viewModel.isRecording,
                    currentPhase: liveAnalyzer.currentPhase,
                    latestFeedback: liveAnalyzer.latestFeedback,
                    formGrade: liveAnalyzer.currentFormGrade
                )
                .allowsHitTesting(false)
            }

            VStack {
                Spacer()
                recordingControls
            }
            .padding(.bottom, Spacing.xxl)

            if viewModel.isRecording {
                timerOverlay
            }

            if !viewModel.isRecording && viewModel.isSessionReady {
                positioningGuide
            }

            VStack {
                HStack {
                    Button(action: { switchToSessions() }) {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Sessions")
                                .font(AppFont.body(size: 14, weight: .medium))
                        }
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.35))
                        )
                    }
                    .padding(.top, Spacing.xl)
                    .padding(.leading, Spacing.md)
                    .opacity(viewModel.isRecording ? 0 : 1)
                    .disabled(viewModel.isRecording)

                    Spacer()
                }

                Spacer()
            }
        }
    }

    // MARK: - Session Saved Screen

    private var sessionSavedScreen: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(theme.success)

                VStack(spacing: Spacing.xs) {
                    Text("Session Saved!")
                        .font(AppFont.display(size: 28))
                        .foregroundStyle(theme.textPrimary)

                    Text("Your recording is ready for\nAI analysis")
                        .font(AppFont.body(size: 16))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                Spacer()

                VStack(spacing: Spacing.md) {
                    Button(action: {
                        viewModel.dismissSavedOverlay()
                        switchToSessions()
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "list.bullet.rectangle.fill")
                                .font(.system(size: 16))
                            Text("View Sessions")
                        }
                        .font(AppFont.body(size: 17, weight: .semibold))
                        .foregroundStyle(theme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .fill(theme.accent)
                        )
                    }

                    Button(action: { viewModel.dismissSavedOverlay() }) {
                        Text("Record Another")
                            .font(AppFont.body(size: 16, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .stroke(theme.textTertiary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
    }

    // MARK: - Positioning Guide

    private var positioningGuide: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "figure.tennis")
                .font(.system(size: 40))
                .foregroundStyle(theme.accent.opacity(0.6))

            Text("Position your phone \(AppConstants.Camera.recommendedDistance) away")
                .font(AppFont.body(size: 14))
                .foregroundStyle(theme.textSecondary)

            Text("at \(AppConstants.Camera.recommendedHeight.lowercased())")
                .font(AppFont.body(size: 14))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(theme.surfacePrimary.opacity(0.85))
        )
    }

    // MARK: - Recording Controls

    private var recordingControls: some View {
        HStack(spacing: Spacing.xxl) {
            liveModeToggle

            if viewModel.isRecording {
                Button(action: { viewModel.stopRecording() }) {
                    ZStack {
                        Circle()
                            .fill(theme.error.opacity(0.2))
                            .frame(width: 80, height: 80)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.error)
                            .frame(width: 28, height: 28)
                    }
                }
            } else {
                Button(action: { viewModel.startRecording(context: modelContext) }) {
                    ZStack {
                        Circle()
                            .strokeBorder(theme.accent, lineWidth: 4)
                            .frame(width: 80, height: 80)

                        Circle()
                            .fill(theme.accent)
                            .frame(width: 64, height: 64)
                    }
                }
                .disabled(!viewModel.isSessionReady)
                .opacity(viewModel.isSessionReady ? 1 : 0.4)
            }

            Color.clear.frame(width: 48, height: 48)
        }
    }

    private var liveModeToggle: some View {
        Button(action: {
            liveModeEnabled.toggle()
            voiceFeedback.isEnabled = liveModeEnabled
        }) {
            VStack(spacing: 3) {
                Image(systemName: liveModeEnabled ? "waveform.circle.fill" : "waveform.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(liveModeEnabled ? theme.accentSecondary : .white.opacity(0.6))

                Text("Live")
                    .font(AppFont.body(size: 10, weight: .semibold))
                    .foregroundStyle(liveModeEnabled ? theme.accentSecondary : .white.opacity(0.6))
            }
            .frame(width: 48, height: 48)
        }
    }

    // MARK: - Timer Overlay

    private var timerOverlay: some View {
        VStack {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(theme.error)
                    .frame(width: 10, height: 10)

                Text(viewModel.formattedDuration)
                    .font(AppFont.mono(size: 18))
                    .foregroundStyle(theme.textPrimary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(theme.surfacePrimary.opacity(0.8))
            )
            .padding(.top, Spacing.xxl)

            Spacer()
        }
    }
}

// MARK: - Camera Preview UIKit Bridge

struct CameraPreviewRepresentable: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer = previewLayer
    }
}

class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            guard let previewLayer else { return }
            previewLayer.frame = bounds
            previewLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(previewLayer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
```


## FILE: TennisIQ/Views/Record/SignInView.swift
```swift
import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var authService: AuthService
    let theme = DesignSystem.current

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: Spacing.xxl) {
                Spacer()

                VStack(spacing: Spacing.lg) {
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 72, weight: .thin))
                        .foregroundStyle(theme.accent)

                    Text("TennisCoach")
                        .font(AppFont.display(size: 36))
                        .foregroundStyle(theme.textPrimary)
                    +
                    Text("AI")
                        .font(AppFont.display(size: 36))
                        .foregroundStyle(theme.accent)

                    Text("World-class coaching\nthrough your phone")
                        .font(AppFont.body(size: 18))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                VStack(spacing: Spacing.md) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        authService.handleSignInResult(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .cornerRadius(Radius.md)

                    Button {
                        authService.continueAsGuest()
                    } label: {
                        Text("Continue as Guest")
                            .font(AppFont.body(size: 16, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .stroke(theme.textTertiary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    Text("Your data stays private. Videos never leave your device.")
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
        }
    }
}
```


## FILE: TennisIQ/Views/Sessions/AnalysisResultsView.swift
```swift
import SwiftUI
import AVKit
import AVFoundation
import Combine
import CoreMedia

// MARK: - Playback ViewModel

@MainActor
final class PlaybackViewModel: ObservableObject {
    @Published var currentJoints: [JointData] = []
    @Published var currentTime: Double = 0
    @Published var isPlaying = false
    @Published var selectedSpeed: Float = 1.0
    @Published var autoSlowEnabled = true
    @Published var isInStrokeWindow = false
    @Published var videoNaturalSize: CGSize = CGSize(width: 1080, height: 1920)
    @Published var racketTrajectory: [CGPoint] = []
    @Published var smoothedJoints: [JointData] = []

    let player: AVPlayer
    private let videoURL: URL
    private var timeObserverToken: Any?
    private var sortedFrames: [FramePoseData] = []
    private var strokeWindows: [(start: Double, end: Double)] = []
    private let maxTrajectoryPoints = 60
    private var rawTrajectoryBuffer: [CGPoint] = []
    private var previousSmoothedJoints: [String: (x: Double, y: Double)] = [:]
    private let smoothingFactor: Double = 0.35

    init(url: URL) {
        self.videoURL = url
        self.player = AVPlayer(playerItem: AVPlayerItem(url: url))
    }

    func configure(frames: [FramePoseData], strokes: [StrokeAnalysisModel]) {
        sortedFrames = frames.sorted { $0.timestamp < $1.timestamp }
        strokeWindows = strokes.map { (start: max(0, $0.timestamp - 1.0), end: $0.timestamp + 1.0) }
        attachTimeObserver()
        loadVideoSize()
    }

    private func loadVideoSize() {
        Task {
            let asset = AVURLAsset(url: videoURL)
            if let track = try? await asset.loadTracks(withMediaType: .video).first {
                let size = try? await track.load(.naturalSize)
                let transform = try? await track.load(.preferredTransform)
                if let size, let transform {
                    let transformed = size.applying(transform)
                    let absolute = CGSize(
                        width: abs(transformed.width),
                        height: abs(transformed.height)
                    )
                    await MainActor.run {
                        self.videoNaturalSize = absolute
                    }
                }
            }
        }
    }

    private func attachTimeObserver() {
        let interval = CMTime(value: 1, timescale: 30)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.handleTimeUpdate(time.seconds)
            }
        }
    }

    private func handleTimeUpdate(_ seconds: Double) {
        currentTime = seconds

        if let frame = nearestFrame(to: seconds) {
            currentJoints = frame.joints
            smoothedJoints = applySmoothingToJoints(frame.joints)

            let hand = Handedness.current
            let wristName = hand.dominantWrist
            let elbowName = hand.dominantElbow

            if let wrist = frame.joints.first(where: { $0.name == wristName }),
               wrist.confidence > 0.3 {
                let racketHead: CGPoint
                if let elbow = frame.joints.first(where: { $0.name == elbowName }),
                   elbow.confidence > 0.3 {
                    let dx = wrist.x - elbow.x
                    let dy = wrist.y - elbow.y
                    racketHead = CGPoint(x: wrist.x + dx * 0.6, y: wrist.y + dy * 0.6)
                } else {
                    racketHead = CGPoint(x: wrist.x, y: wrist.y)
                }

                rawTrajectoryBuffer.append(racketHead)
                if rawTrajectoryBuffer.count > maxTrajectoryPoints {
                    rawTrajectoryBuffer.removeFirst()
                }
                racketTrajectory = smoothTrajectory(rawTrajectoryBuffer)
            }
        }

        let inWindow = strokeWindows.contains { seconds >= $0.start && seconds <= $0.end }
        if inWindow != isInStrokeWindow {
            isInStrokeWindow = inWindow
            if !inWindow {
                rawTrajectoryBuffer.removeAll()
                racketTrajectory.removeAll()
            }
        }

        if autoSlowEnabled && inWindow {
            if player.rate != 0 && player.rate != 0.25 {
                player.rate = 0.25
            }
        } else if autoSlowEnabled && !inWindow {
            if player.rate != 0 && player.rate != selectedSpeed {
                player.rate = selectedSpeed
            }
        }
    }

    func seekTo(timestamp: Double) {
        let time = CMTime(seconds: timestamp, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        pause()
        rawTrajectoryBuffer.removeAll()
        racketTrajectory.removeAll()
        handleTimeUpdate(timestamp)
    }

    private func applySmoothingToJoints(_ joints: [JointData]) -> [JointData] {
        joints.map { joint in
            if let prev = previousSmoothedJoints[joint.name] {
                let smoothX = prev.x + smoothingFactor * (joint.x - prev.x)
                let smoothY = prev.y + smoothingFactor * (joint.y - prev.y)
                previousSmoothedJoints[joint.name] = (x: smoothX, y: smoothY)
                return JointData(name: joint.name, x: smoothX, y: smoothY, confidence: joint.confidence)
            } else {
                previousSmoothedJoints[joint.name] = (x: joint.x, y: joint.y)
                return joint
            }
        }
    }

    private func smoothTrajectory(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 4 else { return points }

        var smoothed: [CGPoint] = []
        for i in 1..<(points.count - 2) {
            let p0 = points[i - 1]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[i + 2]

            for t in stride(from: 0.0, to: 1.0, by: 0.5) {
                let tt = t * t
                let ttt = tt * t
                let x = 0.5 * ((2 * p1.x) +
                    (-p0.x + p2.x) * t +
                    (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * tt +
                    (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * ttt)
                let y = 0.5 * ((2 * p1.y) +
                    (-p0.y + p2.y) * t +
                    (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * tt +
                    (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * ttt)
                smoothed.append(CGPoint(x: x, y: y))
            }
        }
        return smoothed
    }

    private func nearestFrame(to time: Double) -> FramePoseData? {
        guard !sortedFrames.isEmpty else { return nil }

        var lo = 0
        var hi = sortedFrames.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if sortedFrames[mid].timestamp < time {
                lo = mid + 1
            } else {
                hi = mid
            }
        }

        if lo == 0 { return sortedFrames[0] }
        if lo >= sortedFrames.count { return sortedFrames.last }

        let before = sortedFrames[lo - 1]
        let after = sortedFrames[lo]
        return abs(before.timestamp - time) <= abs(after.timestamp - time) ? before : after
    }

    func play() {
        player.rate = autoSlowEnabled && isInStrokeWindow ? 0.25 : selectedSpeed
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func setSpeed(_ speed: Float) {
        selectedSpeed = speed
        if isPlaying && !(autoSlowEnabled && isInStrokeWindow) {
            player.rate = speed
        }
    }

    func cleanup() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player.pause()
    }
}

// MARK: - AVPlayerLayer UIViewRepresentable

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerContainerUIView {
        PlayerContainerUIView(player: player)
    }

    func updateUIView(_ uiView: PlayerContainerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

final class PlayerContainerUIView: UIView {
    let playerLayer: AVPlayerLayer

    init(player: AVPlayer) {
        self.playerLayer = AVPlayerLayer(player: player)
        super.init(frame: .zero)
        playerLayer.videoGravity = .resizeAspectFill
        clipsToBounds = true
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

// MARK: - Main Analysis Results View

struct AnalysisResultsView: View {
    let session: SessionModel
    @StateObject private var viewModel: AnalysisViewModel
    @StateObject private var playback: PlaybackViewModel
    @State private var showOverlay = true
    @State private var showSwingPath = false
    @State private var selectedStroke: StrokeAnalysisModel?
    @State private var selectedPhase: SwingPhase?
    @State private var showFeedbackPrompt = false
    @State private var showProComparison = false
    @EnvironmentObject var authService: AuthService
    @Environment(\.modelContext) private var modelContext

    private let theme = DesignSystem.current
    private let analytics = AnalyticsService.shared

    init(session: SessionModel) {
        self.session = session
        _viewModel = StateObject(wrappedValue: AnalysisViewModel(session: session))

        let url: URL? = {
            guard let filename = session.videoLocalURL else { return nil }
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = docs.appendingPathComponent(filename)
            return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
        }()
        let dummyURL = URL(string: "about:blank")!
        _playback = StateObject(wrappedValue: PlaybackViewModel(url: url ?? dummyURL))
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if viewModel.isLoading {
                AnalysisLoadingContent(phase: viewModel.analysisPhase, progress: viewModel.poseProgress)
            } else if session.status == .failed {
                AnalysisFailedContent(error: viewModel.error) {
                    session.status = .processing
                    Task { await viewModel.triggerAnalysis(context: modelContext) }
                }
            } else {
                analysisContent
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(session.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if session.status != .failed && !viewModel.isLoading {
                    Button(action: shareAnalysis) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.accent)
                    }
                }
            }
        }
        .overlay {
            if showFeedbackPrompt {
                FeedbackPromptView(isPresented: $showFeedbackPrompt) { rating, comment in
                    Task {
                        await FeedbackService.shared.submitFeedback(
                            userID: authService.currentUserID,
                            rating: rating,
                            comment: comment
                        )
                    }
                }
                .transition(.opacity)
            }
        }
        .task {
            if viewModel.needsAnalysis {
                await viewModel.triggerAnalysis(context: modelContext)
            }
            if selectedStroke == nil {
                selectedStroke = session.strokeAnalyses.first
            }
            playback.configure(frames: session.poseFrames, strokes: session.strokeAnalyses)
        }
        .onDisappear {
            playback.cleanup()
        }
        .onChange(of: viewModel.isLoading) { wasLoading, isLoading in
            if wasLoading && !isLoading && session.status != .failed {
                analytics.trackEvent(.analysisCompleted(
                    strokeCount: session.strokeAnalyses.count,
                    overallGrade: session.overallGrade ?? "N/A"
                ))
                if analytics.shouldShowFeedbackPrompt {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        analytics.trackEvent(.feedbackPromptShown)
                        withAnimation { showFeedbackPrompt = true }
                    }
                }
            }
        }
    }

    private func shareAnalysis() {
        analytics.trackEvent(.shareAnalysisTapped)
        guard let stroke = selectedStroke ?? session.strokeAnalyses.first else { return }
        guard let image = ShareService.shared.generateShareImage(
            grade: stroke.grade,
            strokeType: stroke.strokeType.displayName,
            joints: playback.currentJoints,
            videoSize: playback.videoNaturalSize
        ) else { return }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        ShareService.shared.presentShareSheet(image: image, from: rootVC)
    }

    private var highlightedJointNames: Set<String> {
        guard let phase = selectedPhase,
              let stroke = selectedStroke,
              let breakdown = stroke.phaseBreakdown,
              let detail = breakdown.detail(for: phase)
        else { return [] }

        let side = Handedness.current == .right ? "right" : "left"
        var joints = Set<String>()
        for angle in detail.keyAngles {
            let lower = angle.lowercased()
            if lower.contains("elbow") { joints.insert("\(side)_elbow") }
            if lower.contains("shoulder") { joints.insert("\(side)_shoulder"); joints.insert("left_shoulder"); joints.insert("right_shoulder") }
            if lower.contains("wrist") { joints.insert("\(side)_wrist") }
            if lower.contains("knee") { joints.insert("\(side)_knee") }
            if lower.contains("hip") { joints.insert("\(side)_hip") }
            if lower.contains("ankle") { joints.insert("\(side)_ankle") }
            if lower.contains("spine") || lower.contains("torso") || lower.contains("rotation") {
                joints.insert("left_shoulder"); joints.insert("right_shoulder")
                joints.insert("left_hip"); joints.insert("right_hip")
            }
        }
        return joints
    }

    private var analysisContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack {
                    LiveVideoPlayerSection(
                        playback: playback,
                        showOverlay: $showOverlay,
                        showSwingPath: $showSwingPath,
                        hasVideo: session.videoLocalURL != nil
                    )

                    if showSwingPath && !playback.racketTrajectory.isEmpty {
                        SwingPathOverlayView(
                            wristPoints: playback.racketTrajectory,
                            videoNaturalSize: playback.videoNaturalSize
                        )
                        .containerRelativeFrame(.vertical) { height, _ in
                            height * 0.62
                        }
                        .allowsHitTesting(false)
                    }

                    if showOverlay && !playback.smoothedJoints.isEmpty {
                        WireframeOverlayView(
                            joints: playback.smoothedJoints,
                            videoNaturalSize: playback.videoNaturalSize,
                            highlightedJoints: highlightedJointNames,
                            highlightAngles: selectedPhaseAngles
                        )
                        .containerRelativeFrame(.vertical) { height, _ in
                            height * 0.62
                        }
                        .allowsHitTesting(false)
                    }
                }
                .clipped()

                if showOverlay {
                    OverlayInfoBadges(selectedStroke: selectedStroke)
                }

                StrokeTimelineStrip(
                    strokes: session.strokeAnalyses,
                    selectedStroke: $selectedStroke
                )

                if let stroke = selectedStroke, let breakdown = stroke.phaseBreakdown {
                    PhaseTimelineStrip(
                        breakdown: breakdown,
                        selectedPhase: $selectedPhase,
                        onPhaseSelected: { phase in
                            if let detail = breakdown.detail(for: phase) {
                                playback.seekTo(timestamp: detail.timestamp)
                            }
                        }
                    )
                }

                SessionSummaryCard(
                    session: session,
                    analysisCategories: selectedStroke?.analysisCategories
                )

                ProCompareButton(
                    strokeType: selectedStroke?.strokeType ?? .forehand,
                    onTap: { showProComparison = true }
                )

                StrokeCardsSection(strokes: session.strokeAnalyses)

                TacticalNotesCard(notes: session.tacticalNotes)
            }
        }
        .sheet(isPresented: $showProComparison) {
            if let stroke = selectedStroke {
                ProComparisonSheetView(
                    strokeType: stroke.strokeType,
                    userJoints: playback.currentJoints
                )
            }
        }
    }

    private var selectedPhaseAngles: [String] {
        guard let phase = selectedPhase,
              let stroke = selectedStroke,
              let breakdown = stroke.phaseBreakdown,
              let detail = breakdown.detail(for: phase)
        else { return [] }
        return detail.keyAngles
    }
}

// MARK: - Loading Content

struct AnalysisLoadingContent: View {
    let phase: AnalysisViewModel.AnalysisPhase
    let progress: Double
    private let theme = DesignSystem.current

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            loadingBody
            Spacer()
        }
    }

    @ViewBuilder
    private var loadingBody: some View {
        switch phase {
        case .extractingPoses:
            VStack(spacing: Spacing.md) {
                ProgressView(value: progress)
                    .tint(theme.accent)
                    .frame(width: 200)

                Image(systemName: "figure.run")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(theme.accent)

                Text("Extracting Poses...")
                    .font(AppFont.display(size: 20))
                    .foregroundStyle(theme.textPrimary)

                Text("Analyzing your body movements\nframe by frame")
                    .font(AppFont.body(size: 14))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

        case .sendingToAPI:
            VStack(spacing: Spacing.md) {
                ProgressView()
                    .tint(theme.accent)
                    .scaleEffect(1.5)

                Image(systemName: "brain")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(theme.accentSecondary)

                Text("AI Coach Analyzing...")
                    .font(AppFont.display(size: 20))
                    .foregroundStyle(theme.textPrimary)

                Text("Your coach is reviewing\nyour technique")
                    .font(AppFont.body(size: 14))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

        default:
            ProgressView()
                .tint(theme.accent)
        }
    }
}

// MARK: - Failed Content

struct AnalysisFailedContent: View {
    let error: String?
    let onRetry: () -> Void
    private let theme = DesignSystem.current

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(theme.error)

            Text("Analysis Failed")
                .font(AppFont.display(size: 22))
                .foregroundStyle(theme.textPrimary)

            if let error, !error.isEmpty {
                Text(error)
                    .font(AppFont.body(size: 14))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onRetry) {
                Text("Retry Analysis")
                    .font(AppFont.body(size: 16, weight: .medium))
                    .foregroundStyle(theme.textOnAccent)
                    .frame(width: 200, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .fill(theme.accent)
                    )
            }
        }
    }
}

// MARK: - Live Video Player Section (AVPlayer + real-time overlay)

struct LiveVideoPlayerSection: View {
    @ObservedObject var playback: PlaybackViewModel
    @Binding var showOverlay: Bool
    @Binding var showSwingPath: Bool
    let hasVideo: Bool
    private let theme = DesignSystem.current

    var body: some View {
        if hasVideo {
            ZStack {
                PlayerLayerView(player: playback.player)
                    .containerRelativeFrame(.vertical) { height, _ in
                        height * 0.62
                    }
                    .clipped()
                    .onTapGesture { playback.togglePlayPause() }

                VideoControlsOverlay(
                    playback: playback,
                    showOverlay: $showOverlay,
                    showSwingPath: $showSwingPath
                )
            }
            .clipped()
        } else {
            noVideoPlaceholder
        }
    }

    private var noVideoPlaceholder: some View {
        Rectangle()
            .fill(theme.surfaceSecondary)
            .containerRelativeFrame(.vertical) { height, _ in
                height * 0.62
            }
            .overlay {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.textTertiary)
                    Text("Video not available")
                        .font(AppFont.body(size: 14))
                        .foregroundStyle(theme.textTertiary)
                }
            }
    }
}

// MARK: - Video Controls Overlay

struct VideoControlsOverlay: View {
    @ObservedObject var playback: PlaybackViewModel
    @Binding var showOverlay: Bool
    @Binding var showSwingPath: Bool
    private let theme = DesignSystem.current

    var body: some View {
        VStack {
            topControls
            Spacer()
            bottomControls
        }
    }

    private var topControls: some View {
        HStack {
            if playback.isInStrokeWindow && playback.autoSlowEnabled {
                StrokeWindowBadge()
            }
            Spacer()
            overlayToggleButton
        }
        .padding(Spacing.sm)
    }

    private var bottomControls: some View {
        HStack(spacing: Spacing.sm) {
            PlayPauseButton(isPlaying: playback.isPlaying) {
                playback.togglePlayPause()
            }

            SpeedPicker(
                selectedSpeed: playback.selectedSpeed,
                onSelect: { playback.setSpeed($0) }
            )

            Spacer()

            swingPathToggleButton

            AutoSlowToggle(
                isEnabled: playback.autoSlowEnabled,
                onToggle: { playback.autoSlowEnabled.toggle() }
            )
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    private var overlayToggleButton: some View {
        Button(action: { showOverlay.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: showOverlay ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 12))
                Text("Overlay")
                    .font(AppFont.body(size: 12, weight: .medium))
            }
            .foregroundStyle(showOverlay ? theme.textOnAccent : theme.textSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(showOverlay ? theme.accent : theme.surfaceElevated.opacity(0.85))
            )
        }
    }

    private var swingPathToggleButton: some View {
        Button(action: { showSwingPath.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    .font(.system(size: 11))
                Text("Path")
                    .font(AppFont.body(size: 12, weight: .medium))
            }
            .foregroundStyle(showSwingPath ? theme.textOnAccent : .white.opacity(0.8))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(showSwingPath ? theme.accentSecondary : Color.black.opacity(0.3))
            )
        }
    }
}

// MARK: - Play/Pause Button

struct PlayPauseButton: View {
    let isPlaying: Bool
    let onTap: () -> Void
    private let theme = DesignSystem.current

    var body: some View {
        Button(action: onTap) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 14))
                .foregroundStyle(theme.textOnAccent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(theme.accent.opacity(0.85)))
        }
    }
}

// MARK: - Speed Picker

struct SpeedPicker: View {
    let selectedSpeed: Float
    let onSelect: (Float) -> Void
    private let theme = DesignSystem.current
    private let speeds: [Float] = [0.25, 0.5, 1.0]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(speeds, id: \.self) { speed in
                Button(action: { onSelect(speed) }) {
                    Text(speedLabel(speed))
                        .font(AppFont.mono(size: 11, weight: .bold))
                        .foregroundStyle(selectedSpeed == speed ? theme.textOnAccent : .white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(selectedSpeed == speed ? theme.accent : Color.black.opacity(0.3))
                        )
                }
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
        )
    }

    private func speedLabel(_ speed: Float) -> String {
        if speed == 1.0 { return "1x" }
        return String(format: "%.2gx", speed)
    }
}

// MARK: - Auto Slow-Mo Toggle

struct AutoSlowToggle: View {
    let isEnabled: Bool
    let onToggle: () -> Void
    private let theme = DesignSystem.current

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 4) {
                Image(systemName: "hare")
                    .font(.system(size: 11))
                Text("Auto Slow")
                    .font(AppFont.body(size: 11, weight: .medium))
            }
            .foregroundStyle(isEnabled ? theme.textOnAccent : .white.opacity(0.8))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isEnabled ? theme.accent.opacity(0.85) : Color.black.opacity(0.4))
            )
        }
    }
}

// MARK: - Stroke Window Badge

struct StrokeWindowBadge: View {
    private let theme = DesignSystem.current

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "figure.tennis")
                .font(.system(size: 10, weight: .bold))
            Text("STROKE")
                .font(AppFont.mono(size: 10, weight: .bold))
                .tracking(0.5)
        }
        .foregroundStyle(theme.textOnAccent)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(theme.accentSecondary.opacity(0.85))
        )
    }
}

// MARK: - Overlay Info Badges

struct OverlayInfoBadges: View {
    let selectedStroke: StrokeAnalysisModel?
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let stroke = selectedStroke, let overlay = stroke.overlayInstructions {
                if overlay.anglesToHighlight.isEmpty {
                    Text("No angle data for this stroke")
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, Spacing.md)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(overlay.anglesToHighlight, id: \.self) { angle in
                                AngleBadge(text: angle)
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                    }
                }
            } else {
                Text("Select a stroke to see pose data")
                    .font(AppFont.body(size: 12))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, Spacing.md)
            }
        }
        .padding(.vertical, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfacePrimary)
    }
}

struct AngleBadge: View {
    let text: String
    private let theme = DesignSystem.current

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "angle")
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(AppFont.mono(size: 11))
        }
        .foregroundStyle(theme.accent)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(theme.accentMuted)
        )
    }
}

// MARK: - Stroke Timeline Strip

struct StrokeTimelineStrip: View {
    let strokes: [StrokeAnalysisModel]
    @Binding var selectedStroke: StrokeAnalysisModel?
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("STROKE TIMELINE")
                .font(AppFont.body(size: 11, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(strokes) { stroke in
                        StrokeTimelineMarker(
                            stroke: stroke,
                            isSelected: selectedStroke?.id == stroke.id,
                            onTap: { selectedStroke = stroke }
                        )
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
        .padding(.vertical, Spacing.md)
        .background(theme.surfacePrimary)
    }
}

struct StrokeTimelineMarker: View {
    let stroke: StrokeAnalysisModel
    let isSelected: Bool
    let onTap: () -> Void
    private let theme = DesignSystem.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: stroke.strokeType.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? theme.textOnAccent : theme.textSecondary)

                Text(stroke.grade)
                    .font(AppFont.mono(size: 11, weight: .bold))
                    .foregroundStyle(isSelected ? theme.textOnAccent : gradeColor)
            }
            .frame(width: 48, height: 48)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(isSelected ? theme.accent : theme.surfaceSecondary)
            )
        }
        .buttonStyle(.plain)
    }

    private var gradeColor: Color {
        switch stroke.grade.prefix(1) {
        case "A": return theme.success
        case "B": return theme.accent
        case "C": return theme.warning
        default: return theme.error
        }
    }
}

// MARK: - Session Summary Card

struct SessionSummaryCard: View {
    let session: SessionModel
    var analysisCategories: [AnalysisCategory]? = nil
    private let theme = DesignSystem.current

    var body: some View {
        VStack(spacing: Spacing.md) {
            headerRow
            if let priority = session.topPriority {
                priorityBanner(priority)
            }
            if let categories = analysisCategories, !categories.isEmpty {
                reportCardSection(categories)
            }
        }
        .padding(Spacing.md)
        .background(theme.surfacePrimary)
        .padding(.top, 1)
    }

    private func reportCardSection(_ categories: [AnalysisCategory]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 5) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.accent)
                Text("SWING ANALYSIS")
                    .font(AppFont.body(size: 11, weight: .bold))
                    .foregroundStyle(theme.accent)
                    .tracking(0.5)
            }

            ForEach(categories) { category in
                ReportCategoryRow(category: category)
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Session Grade")
                    .font(AppFont.body(size: 12))
                    .foregroundStyle(theme.textTertiary)

                Text(session.overallGrade ?? "--")
                    .font(AppFont.display(size: 44))
                    .foregroundStyle(theme.accent)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(formattedDuration)
                        .font(AppFont.mono(size: 13))
                }
                .foregroundStyle(theme.textSecondary)

                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 12))
                    Text("\(session.strokeAnalyses.count) strokes")
                        .font(AppFont.mono(size: 13))
                }
                .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func priorityBanner(_ text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "target")
                .font(.system(size: 14))
                .foregroundStyle(theme.accent)

            Text("Top Priority: \(text)")
                .font(AppFont.body(size: 14, weight: .medium))
                .foregroundStyle(theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(theme.accentMuted)
        )
    }

    private var formattedDuration: String {
        let m = session.durationSeconds / 60
        let s = session.durationSeconds % 60
        return "\(m)m \(s)s"
    }
}

// MARK: - Stroke Cards Section

struct StrokeCardsSection: View {
    let strokes: [StrokeAnalysisModel]

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(strokes) { stroke in
                CoachingCard(stroke: stroke)
            }
        }
        .padding(Spacing.md)
    }
}

// MARK: - Coaching Card (Redesigned with 4 sections)

struct CoachingCard: View {
    let stroke: StrokeAnalysisModel
    @State private var isExpanded = false
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            if isExpanded {
                expandedBody
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    private var cardHeader: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
            HStack {
                Image(systemName: stroke.strokeType.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(theme.accent)
                    .frame(width: 32, height: 32)
                    .background(theme.accentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                VStack(alignment: .leading, spacing: 2) {
                    Text(stroke.strokeType.displayName)
                        .font(AppFont.body(size: 15, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    Text(String(format: "@ %.1fs", stroke.timestamp))
                        .font(AppFont.mono(size: 12))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                GradeBadge(grade: stroke.grade)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(Spacing.md)
        }
        .buttonStyle(.plain)
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Divider().foregroundStyle(theme.surfaceSecondary)

            GradeRationaleSection(rationale: stroke.gradingRationale)

            MechanicsBreakdownSection(mechanics: stroke.mechanics)

            ImprovementPlanSection(plan: stroke.nextRepsPlan)

            VerifiedSourcesSection(stroke: stroke)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Grade Badge

struct GradeBadge: View {
    let grade: String
    private let theme = DesignSystem.current

    var body: some View {
        Text(grade)
            .font(AppFont.display(size: 20))
            .foregroundStyle(gradeColor)
            .frame(width: 44, height: 36)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm)
                    .fill(gradeColor.opacity(0.12))
            )
    }

    private var gradeColor: Color {
        switch grade.prefix(1) {
        case "A": return theme.success
        case "B": return theme.accent
        case "C": return theme.warning
        default: return theme.error
        }
    }
}

// MARK: - Section 1: Grade Rationale

struct GradeRationaleSection: View {
    let rationale: String?
    private let theme = DesignSystem.current

    var body: some View {
        if let text = rationale, !text.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SectionLabel(icon: "text.justify.leading", title: "WHY THIS GRADE")

                Text(text)
                    .font(AppFont.body(size: 13))
                    .foregroundStyle(theme.textPrimary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(theme.accentMuted.opacity(0.5))
                    )
            }
        }
    }
}

// MARK: - Section 2: Mechanics Breakdown

struct MechanicsBreakdownSection: View {
    let mechanics: StrokeMechanics?
    private let theme = DesignSystem.current

    var body: some View {
        if let mechanics {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SectionLabel(icon: "gearshape.2", title: "MECHANICS BREAKDOWN")

                mechanicsList(mechanics)
            }
        }
    }

    @ViewBuilder
    private func mechanicsList(_ m: StrokeMechanics) -> some View {
        if let d = m.backswing { ExpandableMechanicRow(name: "Backswing", detail: d) }
        if let d = m.contactPoint { ExpandableMechanicRow(name: "Contact Point", detail: d) }
        if let d = m.followThrough { ExpandableMechanicRow(name: "Follow-Through", detail: d) }
        if let d = m.stance { ExpandableMechanicRow(name: "Stance", detail: d) }
        if let d = m.toss { ExpandableMechanicRow(name: "Toss", detail: d) }
    }
}

// MARK: - Expandable Mechanic Row

struct ExpandableMechanicRow: View {
    let name: String
    let detail: MechanicDetail
    @State private var isExpanded = false
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mechanicHeader
            if isExpanded {
                mechanicDetails
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(theme.surfaceSecondary)
        )
    }

    private var mechanicHeader: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
            HStack {
                Text(name)
                    .font(AppFont.body(size: 13, weight: .medium))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                ScoreBar(score: detail.score)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
    }

    private var mechanicDetails: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(detail.note)
                .font(AppFont.body(size: 12))
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(2)

            if let why = detail.whyScore, !why.isEmpty {
                MechanicDetailRow(
                    icon: "questionmark.circle",
                    label: "Why this score",
                    text: why,
                    color: theme.textSecondary
                )
            }

            if let cue = detail.improveCue, !cue.isEmpty {
                MechanicDetailRow(
                    icon: "quote.bubble",
                    label: "Coaching Cue",
                    text: cue,
                    color: theme.accent
                )
            }

            if let drill = detail.drill, !drill.isEmpty {
                MechanicDetailRow(
                    icon: "figure.tennis",
                    label: "Practice Drill",
                    text: drill,
                    color: theme.accentSecondary
                )
            }

            if let sources = detail.sources, !sources.isEmpty {
                MechanicSourcesRow(sources: sources)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .transition(.opacity)
    }
}

// MARK: - Mechanic Detail Row

struct MechanicDetailRow: View {
    let icon: String
    let label: String
    let text: String
    let color: Color
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(AppFont.body(size: 11, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(text)
                .font(AppFont.body(size: 12))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(2)
                .padding(.leading, 14)
        }
        .padding(.top, Spacing.xxs)
    }
}

// MARK: - Mechanic Sources Row

struct MechanicSourcesRow: View {
    let sources: [String]
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "book.closed")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                Text("Source")
                    .font(AppFont.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }

            ForEach(sources, id: \.self) { src in
                Text(src)
                    .font(AppFont.body(size: 11))
                    .foregroundStyle(theme.textTertiary)
                    .italic()
                    .padding(.leading, 14)
            }
        }
        .padding(.top, Spacing.xxs)
    }
}

// MARK: - Score Bar

struct ScoreBar: View {
    let score: Int
    private let theme = DesignSystem.current

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...10, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= score ? scoreColor : theme.surfaceSecondary.opacity(0.5))
                    .frame(width: 5, height: 12)
            }
            Text("\(score)")
                .font(AppFont.mono(size: 11, weight: .bold))
                .foregroundStyle(scoreColor)
                .frame(width: 18, alignment: .trailing)
        }
    }

    private var scoreColor: Color {
        switch score {
        case 8...10: return theme.success
        case 5...7: return theme.accent
        case 3...4: return theme.warning
        default: return theme.error
        }
    }
}

// MARK: - Section 3: Improvement Plan

struct ImprovementPlanSection: View {
    let plan: String?
    private let theme = DesignSystem.current

    var body: some View {
        if let text = plan, !text.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SectionLabel(icon: "clipboard", title: "IMPROVEMENT PLAN")

                Text(text)
                    .font(AppFont.body(size: 13))
                    .foregroundStyle(theme.textPrimary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(theme.surfaceSecondary)
                    )
            }
        }
    }
}

// MARK: - Section 4: Verified Sources

struct VerifiedSourcesSection: View {
    let stroke: StrokeAnalysisModel
    private let theme = DesignSystem.current

    var body: some View {
        let allSources = gatherSources()
        if !allSources.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SectionLabel(icon: "checkmark.seal", title: "VERIFIED SOURCES")

                ForEach(allSources, id: \.self) { source in
                    SourceCitationCard(text: source)
                }
            }
        }
    }

    private func gatherSources() -> [String] {
        guard let mechanics = stroke.mechanics else {
            return stroke.verifiedSources
        }
        var all: [String] = []
        all.append(contentsOf: stroke.verifiedSources)
        all.append(contentsOf: mechanics.backswing?.sources ?? [])
        all.append(contentsOf: mechanics.contactPoint?.sources ?? [])
        all.append(contentsOf: mechanics.followThrough?.sources ?? [])
        all.append(contentsOf: mechanics.stance?.sources ?? [])
        all.append(contentsOf: mechanics.toss?.sources ?? [])
        return Array(Set(all)).sorted()
    }
}

struct SourceCitationCard: View {
    let text: String
    private let theme = DesignSystem.current

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 12))
                .foregroundStyle(theme.accentSecondary)
                .padding(.top, 2)

            Text(text)
                .font(AppFont.body(size: 12))
                .foregroundStyle(theme.textSecondary)
                .italic()
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(theme.surfaceSecondary)
        )
    }
}

// MARK: - Section Label Helper

struct SectionLabel: View {
    let icon: String
    let title: String
    private let theme = DesignSystem.current

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.textTertiary)
            Text(title)
                .font(AppFont.body(size: 11, weight: .bold))
                .foregroundStyle(theme.textTertiary)
                .tracking(0.5)
        }
    }
}

// MARK: - Tactical Notes Card

struct TacticalNotesCard: View {
    let notes: [String]
    private let theme = DesignSystem.current

    var body: some View {
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionLabel(icon: "lightbulb", title: "TACTICAL NOTES")

                ForEach(notes, id: \.self) { note in
                    HStack(alignment: .top, spacing: Spacing.xs) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.accentSecondary)
                            .padding(.top, 2)

                        Text(note)
                            .font(AppFont.body(size: 14))
                            .foregroundStyle(theme.textSecondary)
                            .lineSpacing(3)
                    }
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.surfacePrimary)
            )
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xxl)
        }
    }
}

// MARK: - Phase Timeline Strip (integrated above coaching cards)

struct PhaseTimelineStrip: View {
    let breakdown: PhaseBreakdown
    @Binding var selectedPhase: SwingPhase?
    var onPhaseSelected: ((SwingPhase) -> Void)? = nil
    private let theme = DesignSystem.current

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: 5) {
                    Image(systemName: "timeline.selection")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.accent)
                    Text("PHASE BREAKDOWN")
                        .font(AppFont.body(size: 11, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .tracking(0.5)
                }
                .padding(.horizontal, Spacing.md)

                phaseTimeline
            }
            .padding(.vertical, Spacing.md)
            .background(theme.surfacePrimary)

            if let phase = selectedPhase, let detail = breakdown.detail(for: phase) {
                PhaseDetailCard(phase: phase, detail: detail)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.sm)
                    .background(theme.surfacePrimary)
            }
        }
    }

    private var phaseTimeline: some View {
        HStack(spacing: 0) {
            ForEach(breakdown.allPhases, id: \.0) { phase, detail in
                phaseNode(phase: phase, detail: detail)
            }
        }
        .padding(.horizontal, Spacing.sm)
    }

    private func phaseNode(phase: SwingPhase, detail: PhaseDetail?) -> some View {
        let isSelected = selectedPhase == phase
        let score = detail?.score ?? 0
        let status = detail?.status ?? .warning

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                if selectedPhase == phase {
                    selectedPhase = nil
                } else {
                    selectedPhase = phase
                    onPhaseSelected?(phase)
                }
            }
        }) {
            VStack(spacing: 4) {
                Circle()
                    .fill(zoneColor(status))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("\(score)")
                            .font(AppFont.mono(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? theme.accent : .clear, lineWidth: 2.5)
                            .frame(width: 38, height: 38)
                    )
                    .scaleEffect(isSelected ? 1.1 : 1.0)

                Text(phase.displayName)
                    .font(AppFont.body(size: 9, weight: .semibold))
                    .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 24, alignment: .top)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func zoneColor(_ status: ZoneStatus) -> Color {
        switch status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }
}

// MARK: - Report Category Row (inside summary card)

struct ReportCategoryRow: View {
    let category: AnalysisCategory
    private let theme = DesignSystem.current

    var body: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(zoneBgColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: categoryIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(zoneColor)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(category.name)
                    .font(AppFont.body(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                Text(category.description)
                    .font(AppFont.body(size: 11))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(category.status.displayLabel)
                .font(AppFont.body(size: 11, weight: .bold))
                .foregroundStyle(zoneColor)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(zoneBgColor)
                )
        }
        .padding(.vertical, 4)
    }

    private var categoryIcon: String {
        switch category.name.lowercased() {
        case let n where n.contains("posture"): return "figure.stand"
        case let n where n.contains("swing"): return "arrow.up.forward"
        case let n where n.contains("foot"): return "shoeprints.fill"
        case let n where n.contains("contact"): return "target"
        case let n where n.contains("follow"): return "arrow.turn.up.right"
        case let n where n.contains("spine"): return "arrow.up.and.down"
        default: return "checkmark.circle"
        }
    }

    private var zoneColor: Color {
        switch category.status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }

    private var zoneBgColor: Color {
        switch category.status {
        case .inZone: return theme.success.opacity(0.08)
        case .warning: return theme.warning.opacity(0.08)
        case .outOfZone: return theme.error.opacity(0.07)
        }
    }
}

// MARK: - Pro Compare Button

struct ProCompareButton: View {
    let strokeType: StrokeType
    let onTap: () -> Void
    private let theme = DesignSystem.current

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(theme.accentSecondary)
                    .frame(width: 36, height: 36)
                    .background(theme.accentSecondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Compare to Pro")
                        .font(AppFont.body(size: 14, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    Text("See how your \(strokeType.displayName.lowercased()) stacks up")
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accentSecondary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(theme.accentSecondary.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Pro Comparison Sheet

struct ProComparisonSheetView: View {
    let strokeType: StrokeType
    let userJoints: [JointData]
    @Environment(\.dismiss) private var dismiss
    private let theme = DesignSystem.current
    private let proService = ProComparisonService()

    @State private var selectedPro: ProPlayer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    proSelectorRow
                    comparisonView
                }
            }
            .background(theme.background)
            .navigationTitle("Compare to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppFont.body(size: 15, weight: .medium))
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .onAppear {
            selectedPro = proService.availablePros(for: strokeType).first
        }
    }

    private var proSelectorRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(proService.availablePros(for: strokeType)) { pro in
                    Button(action: { selectedPro = pro }) {
                        VStack(spacing: 4) {
                            Text(pro.icon)
                                .font(.system(size: 24))
                                .frame(width: 48, height: 48)
                                .background(
                                    Circle()
                                        .fill(theme.surfaceSecondary)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    selectedPro?.id == pro.id ? theme.accent : .clear,
                                                    lineWidth: 2.5
                                                )
                                        )
                                )

                            Text(pro.name)
                                .font(AppFont.body(size: 11, weight: .semibold))
                                .foregroundStyle(
                                    selectedPro?.id == pro.id ? theme.accent : theme.textTertiary
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    @ViewBuilder
    private var comparisonView: some View {
        if let pro = selectedPro {
            ProComparisonView(
                userJoints: userJoints,
                proName: pro.name,
                strokeType: strokeType,
                alignmentScores: [],
                windowBadges: []
            )
            .padding(.horizontal, Spacing.md)
        }
    }
}

// MARK: - Wireframe Overlay View

struct WireframeOverlayView: View {
    let joints: [JointData]
    let videoNaturalSize: CGSize
    var highlightedJoints: Set<String> = []
    var highlightAngles: [String] = []
    private let theme = DesignSystem.current

    private static let headJoints: Set<String> = [
        "nose", "left_eye", "right_eye", "left_ear", "right_ear"
    ]

    private let bones: [(String, String)] = [
        ("left_shoulder", "right_shoulder"),
        ("left_shoulder", "left_elbow"),
        ("left_elbow", "left_wrist"),
        ("right_shoulder", "right_elbow"),
        ("right_elbow", "right_wrist"),
        ("left_shoulder", "left_hip"),
        ("right_shoulder", "right_hip"),
        ("left_hip", "right_hip"),
        ("left_hip", "left_knee"),
        ("left_knee", "left_ankle"),
        ("right_hip", "right_knee"),
        ("right_knee", "right_ankle")
    ]

    private var bodyJoints: [JointData] {
        joints.filter { !Self.headJoints.contains($0.name) }
    }

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let map = Dictionary(uniqueKeysWithValues: bodyJoints.map { ($0.name, $0) })
            let crop = aspectFillCrop(videoSize: videoNaturalSize, viewSize: geo.size)

            ZStack {
                Canvas { context, size in
                    let c = aspectFillCrop(videoSize: videoNaturalSize, viewSize: size)
                    for (a, b) in bones {
                        guard let ja = map[a], let jb = map[b] else { continue }
                        let ptA = toScreen(ja, crop: c)
                        let ptB = toScreen(jb, crop: c)

                        let isHighlighted = highlightedJoints.contains(a) || highlightedJoints.contains(b)
                        let lineColor = isHighlighted ? theme.skeletonWarning : theme.trajectoryLine
                        let lineWidth: CGFloat = isHighlighted ? 5 : 3.5

                        var p = Path()
                        p.move(to: ptA)
                        p.addLine(to: ptB)
                        context.stroke(
                            p,
                            with: .color(lineColor.opacity(0.9)),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    }
                }

                ForEach(bodyJoints, id: \.name) { j in
                    let isHighlighted = highlightedJoints.contains(j.name)
                    let pos = toScreen(j, crop: crop)

                    if isHighlighted {
                        Circle()
                            .stroke(theme.skeletonWarning, lineWidth: 2)
                            .frame(width: 22, height: 22)
                            .scaleEffect(pulseScale)
                            .opacity(Double(2.0 - pulseScale))
                            .position(pos)

                        Circle()
                            .fill(theme.skeletonWarning)
                            .frame(width: 12, height: 12)
                            .shadow(color: theme.skeletonWarning.opacity(0.5), radius: 6)
                            .position(pos)
                    } else {
                        Circle()
                            .fill(theme.angleAnnotation)
                            .frame(width: 10, height: 10)
                            .shadow(color: .black.opacity(0.3), radius: 3)
                            .position(pos)
                    }
                }

                ForEach(Array(angleLabelsForDisplay(map: map, crop: crop).enumerated()), id: \.offset) { _, item in
                    Text(item.text)
                        .font(AppFont.mono(size: 10, weight: .bold))
                        .foregroundStyle(theme.skeletonWarning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.7))
                        )
                        .position(x: item.position.x + 40, y: item.position.y - 12)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.5
                }
            }
        }
    }

    private struct AngleLabel {
        let text: String
        let position: CGPoint
    }

    private func angleLabelsForDisplay(map: [String: JointData], crop: CropInfo) -> [AngleLabel] {
        guard !highlightAngles.isEmpty else { return [] }

        let hand = Handedness.current
        let side = hand == .right ? "right" : "left"

        var labels: [AngleLabel] = []
        for angle in highlightAngles {
            let lower = angle.lowercased()
            var jointName: String?
            var computedAngle: Double?

            if lower.contains("elbow") {
                jointName = "\(side)_elbow"
                computedAngle = computeAngle(
                    a: map["\(side)_shoulder"],
                    b: map["\(side)_elbow"],
                    c: map["\(side)_wrist"]
                )
            } else if lower.contains("shoulder") && lower.contains("rotation") {
                jointName = "\(side)_shoulder"
                computedAngle = computeShoulderRotation(map)
            } else if lower.contains("knee") {
                jointName = "\(side)_knee"
                computedAngle = computeAngle(
                    a: map["\(side)_hip"],
                    b: map["\(side)_knee"],
                    c: map["\(side)_ankle"]
                )
            } else if lower.contains("hip") && !lower.contains("rotation") {
                jointName = "\(side)_hip"
                computedAngle = computeAngle(
                    a: map["\(side)_shoulder"],
                    b: map["\(side)_hip"],
                    c: map["\(side)_knee"]
                )
            } else if lower.contains("wrist") {
                jointName = "\(side)_wrist"
            }

            if let name = jointName, let joint = map[name] {
                var displayText = angle
                if let measured = computedAngle {
                    let parts = angle.split(separator: "(")
                    let idealPart = parts.count > 1 ? " (\(parts[1])" : ""
                    let labelKey = angle.split(separator: ":").first.map(String.init) ?? angle
                    displayText = "\(labelKey): \(Int(measured))°\(idealPart)"
                }
                labels.append(AngleLabel(text: displayText, position: toScreen(joint, crop: crop)))
            }
        }
        return labels
    }

    private func computeAngle(a: JointData?, b: JointData?, c: JointData?) -> Double? {
        guard let a = a, let b = b, let c = c else { return nil }
        let ba = (x: a.x - b.x, y: a.y - b.y)
        let bc = (x: c.x - b.x, y: c.y - b.y)
        let dot = ba.x * bc.x + ba.y * bc.y
        let magBA = sqrt(ba.x * ba.x + ba.y * ba.y)
        let magBC = sqrt(bc.x * bc.x + bc.y * bc.y)
        guard magBA > 0, magBC > 0 else { return nil }
        let cosAngle = max(-1, min(1, dot / (magBA * magBC)))
        return acos(cosAngle) * 180 / .pi
    }

    private func computeShoulderRotation(_ map: [String: JointData]) -> Double? {
        guard let ls = map["left_shoulder"], let rs = map["right_shoulder"] else { return nil }
        let dx = rs.x - ls.x
        let dy = rs.y - ls.y
        let angle = atan2(abs(dy), abs(dx)) * 180 / .pi
        return 90 - angle
    }

    private struct CropInfo {
        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
    }

    private func aspectFillCrop(videoSize: CGSize, viewSize: CGSize) -> CropInfo {
        guard videoSize.width > 0, videoSize.height > 0 else {
            return CropInfo(scale: 1, offsetX: 0, offsetY: 0)
        }
        let videoAspect = videoSize.width / videoSize.height
        let viewAspect = viewSize.width / viewSize.height

        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat

        if videoAspect < viewAspect {
            scale = viewSize.width / videoSize.width
            let scaledHeight = videoSize.height * scale
            offsetX = 0
            offsetY = (viewSize.height - scaledHeight) / 2.0
        } else {
            scale = viewSize.height / videoSize.height
            let scaledWidth = videoSize.width * scale
            offsetX = (viewSize.width - scaledWidth) / 2.0
            offsetY = 0
        }
        return CropInfo(scale: scale, offsetX: offsetX, offsetY: offsetY)
    }

    private func toScreen(_ joint: JointData, crop: CropInfo) -> CGPoint {
        let videoX = joint.y * videoNaturalSize.width
        let videoY = joint.x * videoNaturalSize.height
        return CGPoint(
            x: videoX * crop.scale + crop.offsetX,
            y: videoY * crop.scale + crop.offsetY
        )
    }
}
```


## FILE: TennisIQ/Views/Sessions/SessionsListView.swift
```swift
import SwiftUI
import SwiftData

struct SessionsListView: View {
    @Query(sort: \SessionModel.recordedAt, order: .reverse) private var sessions: [SessionModel]
    @Environment(\.modelContext) private var modelContext
    @State private var isRetryingFailed = false
    @State private var retryProgress = 0
    @State private var retryTotal = 0
    let theme = DesignSystem.current

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionsList
                }
            }
            .navigationTitle("Sessions")
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                if failedSessionsCount > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isRetryingFailed ? "Retrying..." : "Retry Failed (\(failedSessionsCount))") {
                            Task { await retryFailedSessions() }
                        }
                        .disabled(isRetryingFailed)
                    }
                }
            }
            .overlay(alignment: .top) {
                if isRetryingFailed {
                    VStack(spacing: Spacing.xs) {
                        ProgressView(value: retryTotal == 0 ? 0 : Double(retryProgress), total: Double(max(retryTotal, 1)))
                            .tint(theme.accent)
                        Text("Retrying failed sessions (\(retryProgress)/\(retryTotal))")
                            .font(AppFont.body(size: 12))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .fill(theme.surfacePrimary)
                    )
                    .padding(.top, Spacing.sm)
                }
            }
        }
    }

    private var failedSessionsCount: Int {
        sessions.filter { $0.status == .failed }.count
    }

    @MainActor
    private func retryFailedSessions() async {
        let failed = sessions.filter { $0.status == .failed }
        guard !failed.isEmpty else { return }

        isRetryingFailed = true
        retryProgress = 0
        retryTotal = failed.count

        for session in failed {
            session.status = .processing
            try? modelContext.save()

            let vm = AnalysisViewModel(session: session)
            await vm.triggerAnalysis(context: modelContext)
            retryProgress += 1
        }

        isRetryingFailed = false
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(sessions) { session in
                    NavigationLink(destination: AnalysisResultsView(session: session)) {
                        SessionRowView(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "video.slash")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(theme.textTertiary)

            VStack(spacing: Spacing.xs) {
                Text("No Sessions Yet")
                    .font(AppFont.display(size: 22))
                    .foregroundStyle(theme.textPrimary)

                Text("Record your first tennis session\nto get AI coaching feedback")
                    .font(AppFont.body(size: 15))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    let session: SessionModel
    let theme = DesignSystem.current

    var body: some View {
        HStack(spacing: Spacing.md) {
            thumbnailView

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(session.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundStyle(theme.textPrimary)

                Text(formattedDuration)
                    .font(AppFont.mono(size: 13))
                    .foregroundStyle(theme.textSecondary)

                statusBadge
            }

            Spacer()

            if let grade = session.overallGrade {
                gradeView(grade)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    private var thumbnailView: some View {
        RoundedRectangle(cornerRadius: Radius.sm)
            .fill(theme.surfaceSecondary)
            .frame(width: 56, height: 56)
            .overlay {
                if let data = session.thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                } else {
                    Image(systemName: "figure.tennis")
                        .foregroundStyle(theme.textTertiary)
                }
            }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusText)
                .font(AppFont.body(size: 12))
                .foregroundStyle(statusColor)
        }
    }

    private func gradeView(_ grade: String) -> some View {
        Text(grade)
            .font(AppFont.display(size: 20))
            .foregroundStyle(theme.accent)
            .frame(width: 44, alignment: .center)
    }

    private var statusColor: Color {
        switch session.status {
        case .ready: return theme.success
        case .analyzing, .processing: return theme.warning
        case .failed: return theme.error
        case .recording: return theme.accent
        }
    }

    private var statusText: String {
        switch session.status {
        case .recording: return "Recording"
        case .processing: return "Processing..."
        case .analyzing: return "Analyzing..."
        case .ready: return "Ready"
        case .failed: return "Failed"
        }
    }

    private var formattedDuration: String {
        let minutes = session.durationSeconds / 60
        let seconds = session.durationSeconds % 60
        return "\(minutes)m \(seconds)s"
    }
}
```


## FILE: TennisIQ/Views/Sessions/SwingAnalysisReportView.swift
```swift
import SwiftUI

struct SwingAnalysisReportView: View {
    let categories: [AnalysisCategory]

    @State private var reportMode: ReportMode = .standard
    private let theme = DesignSystem.current

    enum ReportMode: String, CaseIterable {
        case standard = "Standard"
        case custom = "Custom"
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Picker("Mode", selection: $reportMode) {
                ForEach(ReportMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.md)

            List {
                ForEach(categories) { category in
                    CategoryCard(category: category)
                        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(theme.background)
    }
}

private struct CategoryCard: View {
    let category: AnalysisCategory

    @State private var isExpanded = false
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: Spacing.sm) {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(zoneBgColor)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: categoryIcon)
                                .font(.system(size: 18))
                                .foregroundStyle(zoneColor)
                        )

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(category.name)
                            .font(AppFont.body(size: 15, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)

                        Text(category.description)
                            .font(AppFont.body(size: 12))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(isExpanded ? nil : 1)
                    }

                    Spacer()

                    ZoneIndicator(status: category.status, style: .badge)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Spacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Divider().foregroundStyle(theme.surfaceSecondary)

                    ForEach(category.subchecks) { subcheck in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            ZoneIndicator(status: subcheck.status, style: .dot)

                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(subcheck.checkpoint)
                                    .font(AppFont.body(size: 13, weight: .medium))
                                    .foregroundStyle(theme.textPrimary)

                                Text(subcheck.result)
                                    .font(AppFont.body(size: 12))
                                    .foregroundStyle(theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                    }
                }
                .padding(.bottom, Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    private var categoryIcon: String {
        switch category.name.lowercased() {
        case let n where n.contains("posture"): return "figure.stand"
        case let n where n.contains("swing"): return "arrow.up.forward"
        case let n where n.contains("foot"): return "shoeprints.fill"
        case let n where n.contains("contact"): return "target"
        case let n where n.contains("follow"): return "arrow.turn.up.right"
        case let n where n.contains("spine"): return "arrow.up.and.down"
        default: return "checkmark.circle"
        }
    }

    private var zoneColor: Color {
        switch category.status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }

    private var zoneBgColor: Color {
        switch category.status {
        case .inZone: return theme.success.opacity(0.12)
        case .warning: return theme.warning.opacity(0.12)
        case .outOfZone: return theme.error.opacity(0.1)
        }
    }
}
```


## FILE: backend/app/__init__.py
```python
```


## FILE: backend/app/config.py
```python
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    app_name: str = "TennisIQ API"
    debug: bool = False

    # OpenAI
    openai_api_key: str = ""
    openai_model: str = "gpt-4o"

    # Supabase
    supabase_url: str = ""
    supabase_key: str = ""
    supabase_service_key: str = ""

    # Auth
    apple_team_id: str = ""
    apple_bundle_id: str = "com.tennisiq.app"

    # Rate limits
    max_video_duration_seconds: int = 1800
    max_key_frames: int = 20

    class Config:
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
```


## FILE: backend/app/models.py
```python
from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, Literal
from datetime import datetime


# --- Request Models ---

class JointData(BaseModel):
    name: str
    x: float
    y: float
    confidence: float


class FramePoseData(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    frame_index: int = Field(alias="frameIndex")
    timestamp: float
    joints: list[JointData]
    confidence: float


class MeasuredAngleData(BaseModel):
    value: float
    label: str
    visible: bool


class DetectedPhaseData(BaseModel):
    timestamp: float
    angles: dict[str, MeasuredAngleData] = {}


class DetectedStrokeData(BaseModel):
    type: str
    contact_timestamp: float
    phases: dict[str, DetectedPhaseData] = {}


class SessionPosePayload(BaseModel):
    session_id: str
    duration_seconds: int
    fps: int
    frames: list[FramePoseData]
    key_frame_timestamps: list[float]
    skill_level: str = "beginner"
    handedness: str = "right"
    detected_strokes: list[DetectedStrokeData] = []


class UserProfile(BaseModel):
    display_name: str = ""
    skill_level: str = "beginner"


# --- Response Models ---

ZoneStatus = Literal["in_zone", "warning", "out_of_zone"]


class MechanicDetail(BaseModel):
    score: int = Field(ge=1, le=10)
    note: str
    why_score: Optional[str] = None
    improve_cue: Optional[str] = None
    drill: Optional[str] = None
    sources: list[str] = []


class StrokeMechanics(BaseModel):
    backswing: Optional[MechanicDetail] = None
    contact_point: Optional[MechanicDetail] = None
    follow_through: Optional[MechanicDetail] = None
    stance: Optional[MechanicDetail] = None
    toss: Optional[MechanicDetail] = None


# --- Swing Path Overlay ---

class PathAnnotation(BaseModel):
    label: str
    position: list[float] = Field(min_length=2, max_length=2)
    status: ZoneStatus = "in_zone"


class OverlayInstructions(BaseModel):
    angles_to_highlight: list[str] = []
    trajectory_line: bool = False
    comparison_ghost: bool = False
    swing_path_points: Optional[list[list[float]]] = None
    swing_plane_angle: Optional[float] = None
    path_annotations: Optional[list[PathAnnotation]] = None


# --- 7-Phase Swing Breakdown ---

class PhaseDetail(BaseModel):
    score: int = Field(ge=1, le=10)
    status: ZoneStatus = "in_zone"
    note: str
    timestamp: float
    key_angles: list[str] = []
    improve_cue: Optional[str] = None
    drill: Optional[str] = None


class PhaseBreakdown(BaseModel):
    ready_position: Optional[PhaseDetail] = None
    unit_turn: Optional[PhaseDetail] = None
    backswing: Optional[PhaseDetail] = None
    forward_swing: Optional[PhaseDetail] = None
    contact_point: Optional[PhaseDetail] = None
    follow_through: Optional[PhaseDetail] = None
    recovery: Optional[PhaseDetail] = None


# --- Analysis Report Card Categories ---

class SubCheck(BaseModel):
    checkpoint: str
    result: str
    status: ZoneStatus = "in_zone"


class AnalysisCategory(BaseModel):
    name: str
    description: str
    status: ZoneStatus = "in_zone"
    subchecks: list[SubCheck] = []
    thumbnail_phase: Optional[str] = None


# --- Pro Comparison ---

class AlignmentScore(BaseModel):
    body_group: str
    percentage: int = Field(ge=0, le=100)
    status: ZoneStatus = "in_zone"


class WindowBadge(BaseModel):
    label: str
    status: ZoneStatus = "in_zone"
    phase: str = ""


class ProComparisonResult(BaseModel):
    pro_name: str
    stroke_type: str
    alignment_scores: list[AlignmentScore] = []
    window_badges: list[WindowBadge] = []


# --- Stroke Result (extended) ---

class StrokeResult(BaseModel):
    type: str
    timestamp: float
    grade: str
    mechanics: StrokeMechanics
    overlay_instructions: OverlayInstructions
    grading_rationale: Optional[str] = None
    next_reps_plan: Optional[str] = None
    verified_sources: list[str] = []
    phase_breakdown: Optional[PhaseBreakdown] = None
    analysis_categories: Optional[list[AnalysisCategory]] = None


class AnalysisResponse(BaseModel):
    session_grade: str
    strokes_detected: list[StrokeResult]
    tactical_notes: list[str]
    top_priority: str
    overall_mechanics_score: float
    session_summary: str


class ProgressResponse(BaseModel):
    overall_score: float
    forehand_score: float
    backhand_score: float
    serve_score: float
    volley_score: float
    trend: str
    weekly_focus: str
    sessions_this_week: int
    sessions_this_month: int
    history: list[dict]


class SessionSummaryResponse(BaseModel):
    id: str
    recorded_at: str
    duration_seconds: int
    overall_grade: Optional[str]
    status: str
```


## FILE: backend/app/prompts/__init__.py
```python
```


## FILE: backend/app/prompts/tennis_coach.py
```python
SYSTEM_PROMPT = """You are an elite tennis coach AI. You receive pre-computed stroke data from on-device analysis (timestamps, joint angles, stroke types) and your job is to provide coaching evaluation ONLY.

## CRITICAL RULES
1. You MUST use the timestamps and angles provided in the detected_strokes data. DO NOT invent or override them.
2. If an angle is marked NOT_VISIBLE, say "not measurable from this angle" -- do NOT fabricate a value.
3. You MUST produce one stroke entry for EACH detected stroke provided. Do not skip any.
4. Every phase_breakdown timestamp MUST exactly match what was provided in the detected stroke data.
5. The key_angles in each phase MUST use the measured values provided. Add ideal ranges for comparison.

## Your Role
- Score each phase (1-10) based on the measured angles vs ideal biomechanical ranges
- Assign zone status (in_zone / warning / out_of_zone) based on deviation from ideal
- Write 1-2 sentence coaching notes referencing the actual measured angles
- Provide one coaching cue and one drill per phase
- Generate analysis categories with subchecks
- Identify the single top priority improvement

## Scoring Guidelines
- 1-3: Significant deviation (>30° from ideal range)
- 4-6: Moderate deviation (15-30° from ideal)
- 7-8: Minor deviation (<15° from ideal)
- 9-10: Within ideal range

## Ideal Ranges (for scoring reference)
- Elbow at contact: 155-175°
- Knee bend (ready): 130-155°
- Shoulder rotation (unit turn): 60-90°+
- Hip angle (ready): 155-175°
- Arm extension at contact: 160-180°
"""

ANALYSIS_PROMPT_TEMPLATE = """Evaluate this tennis session. Player skill level: {skill_level}. Player is {handedness}-handed.

## Session Info
- Duration: {duration_seconds}s
- Strokes detected on-device: {stroke_count}

## Pre-Computed Stroke Data
The following strokes were detected by on-device pose analysis. Timestamps and angles are REAL MEASUREMENTS from the video -- use them as-is.

{detected_strokes_summary}

## Instructions
For each detected stroke above, produce a complete analysis with:
1. Grade (A+ through F) based on the measured angles vs ideal ranges
2. phase_breakdown using the EXACT timestamps and angles provided (add ideal ranges for comparison)
3. analysis_categories with subchecks
4. Coaching notes, cues, drills, and improvement plan
5. overlay_instructions with the measured angles formatted for display

Respond with valid JSON:
```json
{{
  "session_grade": "B+",
  "strokes_detected": [
    {{
      "type": "forehand",
      "timestamp": 8.2,
      "grade": "B",
      "grading_rationale": "2-4 sentences referencing the MEASURED angles and how they compare to ideal.",
      "next_reps_plan": "Specific drills with rep counts.",
      "verified_sources": ["Real reference 1", "Real reference 2"],
      "mechanics": {{
        "backswing": {{"score": 6, "note": "Based on measured elbow angle of X vs ideal Y.", "why_score": "...", "improve_cue": "...", "drill": "...", "sources": ["..."]}},
        "contact_point": {{"score": 7, "note": "...", "why_score": "...", "improve_cue": "...", "drill": "...", "sources": ["..."]}},
        "follow_through": {{"score": 8, "note": "...", "why_score": "...", "improve_cue": "...", "drill": "...", "sources": ["..."]}},
        "stance": {{"score": 7, "note": "...", "why_score": "...", "improve_cue": "...", "drill": "...", "sources": ["..."]}}
      }},
      "phase_breakdown": {{
        "ready_position": {{
          "score": 7,
          "status": "in_zone",
          "note": "Use the measured angles to describe what was observed.",
          "timestamp": 6.8,
          "key_angles": ["Knee: 142° (ideal: 130-155°)", "Hip: 168° (ideal: 155-175°)"],
          "improve_cue": "One concise cue.",
          "drill": "Specific drill with reps."
        }},
        "unit_turn": {{"score": 5, "status": "warning", "note": "...", "timestamp": 7.1, "key_angles": ["..."], "improve_cue": "...", "drill": "..."}},
        "backswing": {{"score": 6, "status": "warning", "note": "...", "timestamp": 7.4, "key_angles": ["..."], "improve_cue": "...", "drill": "..."}},
        "forward_swing": {{"score": 7, "status": "in_zone", "note": "...", "timestamp": 7.8, "key_angles": ["..."], "improve_cue": "...", "drill": "..."}},
        "contact_point": {{"score": 7, "status": "in_zone", "note": "...", "timestamp": 8.2, "key_angles": ["..."], "improve_cue": "...", "drill": "..."}},
        "follow_through": {{"score": 8, "status": "in_zone", "note": "...", "timestamp": 8.5, "key_angles": ["..."], "improve_cue": "...", "drill": "..."}},
        "recovery": {{"score": 5, "status": "warning", "note": "...", "timestamp": 9.0, "key_angles": ["..."], "improve_cue": "...", "drill": "..."}}
      }},
      "analysis_categories": [
        {{"name": "Setup Posture", "description": "Ready position and stance", "status": "in_zone", "thumbnail_phase": "ready_position", "subchecks": [{{"checkpoint": "Knee Bend", "result": "Good", "status": "in_zone"}}]}},
        {{"name": "Swing Path", "description": "Racket path through swing", "status": "warning", "thumbnail_phase": "backswing", "subchecks": [{{"checkpoint": "Takeaway", "result": "On Plane", "status": "in_zone"}}]}},
        {{"name": "Footwork", "description": "Movement and positioning", "status": "in_zone", "thumbnail_phase": "ready_position", "subchecks": []}},
        {{"name": "Contact Zone", "description": "Strike position", "status": "in_zone", "thumbnail_phase": "contact_point", "subchecks": []}},
        {{"name": "Follow-Through", "description": "Finish and deceleration", "status": "in_zone", "thumbnail_phase": "follow_through", "subchecks": []}},
        {{"name": "Spine Stability", "description": "Core posture", "status": "in_zone", "thumbnail_phase": "forward_swing", "subchecks": []}},
        {{"name": "Posture at Impact", "description": "Body alignment at contact", "status": "warning", "thumbnail_phase": "contact_point", "subchecks": []}}
      ],
      "overlay_instructions": {{
        "angles_to_highlight": ["Elbow: 140° (ideal: 155-175°)", "Shoulder rotation: 25° (ideal: 60-90°)"],
        "trajectory_line": true,
        "comparison_ghost": false
      }}
    }}
  ],
  "tactical_notes": ["Observation about shot patterns."],
  "top_priority": "Single highest-impact improvement.",
  "overall_mechanics_score": 72.5,
  "session_summary": "2-3 sentence summary."
}}
```

Return ONLY the JSON, no additional text."""


def build_detected_strokes_summary(detected_strokes: list) -> str:
    """Format pre-computed stroke data for the GPT prompt."""
    if not detected_strokes:
        return "No strokes detected on-device."

    lines = []
    for i, stroke in enumerate(detected_strokes):
        s_type = stroke.get("type", stroke.get("type", "unknown"))
        contact_ts = stroke.get("contact_timestamp", 0)
        lines.append(f"\n### Stroke #{i+1}: {s_type} (contact at t={contact_ts:.1f}s)")

        phases = stroke.get("phases", {})
        for phase_name in ["ready_position", "unit_turn", "backswing", "forward_swing", "contact_point", "follow_through", "recovery"]:
            phase = phases.get(phase_name)
            if not phase:
                lines.append(f"  {phase_name}: NOT DETECTED")
                continue

            ts = phase.get("timestamp", 0)
            angles = phase.get("angles", {})
            angle_strs = []
            for key, angle_data in angles.items():
                if isinstance(angle_data, dict):
                    label = angle_data.get("label", key)
                    visible = angle_data.get("visible", True)
                    if visible:
                        angle_strs.append(label)
                    else:
                        angle_strs.append(f"{key}: NOT_VISIBLE")
            angles_text = ", ".join(angle_strs) if angle_strs else "no angles measured"
            lines.append(f"  {phase_name} at t={ts:.1f}s: {angles_text}")

    return "\n".join(lines)


def build_pose_summary(frames: list, max_frames: int = 50) -> str:
    """Condense frame data into a text summary the LLM can process efficiently."""
    if not frames:
        return "No pose data available."

    step = max(1, len(frames) // max_frames)
    sampled = frames[::step]

    lines = []
    for frame in sampled:
        joints_str = ", ".join(
            f"{j['name']}({j['x']:.3f},{j['y']:.3f})"
            for j in frame["joints"]
            if j["confidence"] > 0.3
        )
        lines.append(f"t={frame['timestamp']:.2f}s: {joints_str}")

    return "\n".join(lines)
```


## FILE: backend/app/routes/__init__.py
```python
```


## FILE: backend/app/routes/deps.py
```python
from typing import Optional
import logging

from fastapi import Header, HTTPException
from supabase import create_client, Client

from app.config import get_settings

_supabase_client: Optional[Client] = None
logger = logging.getLogger(__name__)


def get_supabase() -> Client:
    global _supabase_client
    if _supabase_client is None:
        settings = get_settings()
        try:
            _supabase_client = create_client(settings.supabase_url, settings.supabase_service_key)
        except Exception as exc:
            logger.error("Supabase client init failed, continuing without persistence: %s", exc)
            return None  # type: ignore[return-value]
    return _supabase_client


def get_current_user_id(
    authorization: str = Header(
        default="Bearer dev-token",
        description="Bearer token from Apple Sign In",
    ),
) -> str:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")

    settings = get_settings()

    # In debug mode, accept any token and return a dev user ID
    if settings.debug:
        return "dev-user-001"

    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        raise HTTPException(status_code=401, detail="Missing token")

    try:
        from jose import jwt
        payload = jwt.decode(
            token,
            settings.supabase_key,
            algorithms=["HS256"],
            options={"verify_aud": False},
        )
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token payload")
        return user_id
    except Exception:
        raise HTTPException(status_code=401, detail="Token verification failed")
```


## FILE: backend/app/routes/feedback.py
```python
import logging
from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from typing import Optional
from supabase import Client

from app.routes.deps import get_supabase

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/feedback", tags=["feedback"])


class FeedbackPayload(BaseModel):
    user_id: str = "anonymous"
    rating: int = Field(ge=1, le=5)
    comment: str = ""
    app_version: str = ""
    device_model: str = ""
    ios_version: str = ""
    timestamp: Optional[str] = None


@router.post("")
async def submit_feedback(
    payload: FeedbackPayload,
    supabase: Client = Depends(get_supabase),
):
    feedback_data = {
        "user_id": payload.user_id,
        "rating": payload.rating,
        "comment": payload.comment,
        "app_version": payload.app_version,
        "device_model": payload.device_model,
        "ios_version": payload.ios_version,
        "created_at": payload.timestamp or datetime.utcnow().isoformat(),
    }

    try:
        if supabase:
            supabase.table("user_feedback").insert(feedback_data).execute()
            logger.info("Feedback stored: rating=%d user=%s", payload.rating, payload.user_id)
        else:
            logger.warning("Supabase unavailable, logging feedback: %s", feedback_data)
    except Exception as exc:
        logger.error("Failed to store feedback: %s", exc)

    return {"status": "ok"}
```


## FILE: backend/app/routes/progress.py
```python
from fastapi import APIRouter, Depends
from supabase import Client

from app.services.progress_calculator import ProgressCalculator
from app.routes.deps import get_supabase, get_current_user_id

router = APIRouter(prefix="/progress", tags=["progress"])


@router.get("")
async def get_progress(
    user_id: str = Depends(get_current_user_id),
    supabase: Client = Depends(get_supabase),
):
    calculator = ProgressCalculator(supabase)
    return await calculator.get_progress(user_id)
```


## FILE: backend/app/routes/sessions.py
```python
import json
import logging
from uuid import uuid4
from datetime import datetime

from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
from typing import Optional
from supabase import Client

from app.models import SessionPosePayload, AnalysisResponse
from app.services.llm_coaching import LLMCoachingService
from app.services.progress_calculator import ProgressCalculator
from app.routes.deps import get_supabase, get_current_user_id

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/sessions", tags=["sessions"])


@router.post("/analyze", response_model=AnalysisResponse)
async def analyze_session(
    pose_data: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
    supabase: Optional[Client] = Depends(get_supabase),
):
    pose_bytes = await pose_data.read()
    try:
        pose_dict = json.loads(pose_bytes)
        pose_payload = SessionPosePayload(**pose_dict)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid pose data: {e}")

    key_frame_images: list[bytes] = []
    session_id = pose_payload.session_id or str(uuid4())

    if supabase is not None:
        supabase.table("sessions").insert({
            "id": session_id,
            "user_id": user_id,
            "recorded_at": datetime.utcnow().isoformat(),
            "duration_seconds": pose_payload.duration_seconds,
            "status": "analyzing",
        }).execute()

    try:
        coaching = LLMCoachingService()
        result = await coaching.analyze_session(pose_payload, key_frame_images)

        if supabase is not None:
            for stroke in result.strokes_detected:
                stroke_row = {
                    "id": str(uuid4()),
                    "session_id": session_id,
                    "stroke_type": stroke.type,
                    "timestamp": stroke.timestamp,
                    "grade": stroke.grade,
                    "mechanics": stroke.mechanics.model_dump(),
                    "overlay_instructions": stroke.overlay_instructions.model_dump(),
                }
                if stroke.phase_breakdown:
                    stroke_row["phase_breakdown"] = stroke.phase_breakdown.model_dump()
                if stroke.analysis_categories:
                    stroke_row["analysis_categories"] = [c.model_dump() for c in stroke.analysis_categories]
                supabase.table("stroke_analyses").insert(stroke_row).execute()

            supabase.table("sessions").update({
                "status": "ready",
                "overall_grade": result.session_grade,
                "top_priority": result.top_priority,
                "tactical_notes": result.tactical_notes,
            }).eq("id", session_id).execute()

            calculator = ProgressCalculator(supabase)
            await calculator.update_progress(user_id, session_id)

        return result

    except Exception as e:
        logger.error(f"Analysis failed for session {session_id}: {e}")
        if supabase is not None:
            supabase.table("sessions").update({
                "status": "failed",
            }).eq("id", session_id).execute()
        raise HTTPException(status_code=500, detail=f"Analysis failed: {e}")


@router.get("")
def list_sessions(
    user_id: str = Depends(get_current_user_id),
    supabase: Client = Depends(get_supabase),
):
    result = (
        supabase.table("sessions")
        .select("id, recorded_at, duration_seconds, overall_grade, status")
        .eq("user_id", user_id)
        .order("recorded_at", desc=True)
        .execute()
    )
    return result.data or []


@router.get("/{session_id}")
def get_session(
    session_id: str,
    user_id: str = Depends(get_current_user_id),
    supabase: Client = Depends(get_supabase),
):
    session = (
        supabase.table("sessions")
        .select("*")
        .eq("id", session_id)
        .eq("user_id", user_id)
        .single()
        .execute()
    )
    if not session.data:
        raise HTTPException(status_code=404, detail="Session not found")

    strokes = (
        supabase.table("stroke_analyses")
        .select("*")
        .eq("session_id", session_id)
        .order("timestamp")
        .execute()
    )

    return {
        **session.data,
        "strokes": strokes.data or [],
    }
```


## FILE: backend/app/routes/users.py
```python
from fastapi import APIRouter, Depends
from supabase import Client

from app.models import UserProfile
from app.routes.deps import get_supabase, get_current_user_id

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/profile")
def create_or_update_profile(
    profile: UserProfile,
    user_id: str = Depends(get_current_user_id),
    supabase: Client = Depends(get_supabase),
):
    data = {
        "id": user_id,
        "display_name": profile.display_name,
        "skill_level": profile.skill_level,
    }
    result = supabase.table("user_profiles").upsert(data).execute()
    return result.data[0] if result.data else data


@router.get("/profile")
def get_profile(
    user_id: str = Depends(get_current_user_id),
    supabase: Client = Depends(get_supabase),
):
    result = (
        supabase.table("user_profiles")
        .select("*")
        .eq("id", user_id)
        .single()
        .execute()
    )
    return result.data
```


## FILE: backend/app/services/__init__.py
```python
```


## FILE: backend/app/services/llm_coaching.py
```python
import json
import base64
import logging
from io import BytesIO
from openai import AsyncOpenAI
from PIL import Image

from app.config import get_settings
from app.models import AnalysisResponse, SessionPosePayload
from app.prompts.tennis_coach import (
    SYSTEM_PROMPT,
    ANALYSIS_PROMPT_TEMPLATE,
    build_detected_strokes_summary,
)

logger = logging.getLogger(__name__)


class LLMCoachingService:
    def __init__(self):
        settings = get_settings()
        self.client = AsyncOpenAI(api_key=settings.openai_api_key)
        self.model = settings.openai_model

    async def analyze_session(
        self,
        pose_payload: SessionPosePayload,
        key_frame_images: list[bytes],
    ) -> AnalysisResponse:
        detected_strokes_dicts = [s.model_dump() for s in pose_payload.detected_strokes]
        strokes_summary = build_detected_strokes_summary(detected_strokes_dicts)

        handedness = getattr(pose_payload, 'handedness', 'right')
        dominant_side = "left" if handedness == "left" else "right"

        user_prompt = ANALYSIS_PROMPT_TEMPLATE.format(
            skill_level=pose_payload.skill_level,
            handedness=handedness,
            dominant_side=dominant_side,
            duration_seconds=pose_payload.duration_seconds,
            stroke_count=len(pose_payload.detected_strokes),
            detected_strokes_summary=strokes_summary,
        )

        content: list[dict] = [{"type": "text", "text": user_prompt}]

        for img_bytes in key_frame_images[:10]:
            try:
                resized = self._resize_image(img_bytes, max_size=512)
                b64 = base64.b64encode(resized).decode("utf-8")
                content.append({
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{b64}",
                        "detail": "low",
                    },
                })
            except Exception as e:
                logger.warning(f"Failed to process key frame image: {e}")

        logger.info(
            f"Sending analysis request: {len(pose_payload.detected_strokes)} pre-detected strokes, "
            f"{len(key_frame_images)} images, model={self.model}"
        )

        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": content},
            ],
            response_format={"type": "json_object"},
            temperature=0.3,
            max_tokens=8000,
        )

        raw_json = response.choices[0].message.content
        logger.info(f"LLM response received, tokens used: {response.usage.total_tokens}")

        try:
            parsed = json.loads(raw_json)
            return AnalysisResponse(**parsed)
        except (json.JSONDecodeError, Exception) as e:
            logger.error(f"Failed to parse LLM response: {e}\nRaw: {raw_json[:500]}")
            raise ValueError(f"LLM returned invalid analysis format: {e}")

    def _resize_image(self, img_bytes: bytes, max_size: int = 512) -> bytes:
        img = Image.open(BytesIO(img_bytes))
        img.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
        buffer = BytesIO()
        img.save(buffer, format="JPEG", quality=75)
        return buffer.getvalue()
```


## FILE: backend/app/services/progress_calculator.py
```python
import logging
from datetime import datetime, timedelta
from supabase import Client

logger = logging.getLogger(__name__)


class ProgressCalculator:
    def __init__(self, supabase: Client):
        self.supabase = supabase

    async def update_progress(self, user_id: str, session_id: str) -> dict:
        result = (
            self.supabase.table("stroke_analyses")
            .select("*")
            .eq("session_id", session_id)
            .execute()
        )
        strokes = result.data or []

        if not strokes:
            return {}

        stroke_scores: dict[str, list[float]] = {}
        for stroke in strokes:
            stype = stroke["stroke_type"]
            mechanics = stroke.get("mechanics", {})
            scores = [
                v["score"]
                for v in mechanics.values()
                if isinstance(v, dict) and "score" in v
            ]
            if scores:
                stroke_scores.setdefault(stype, []).extend(scores)

        session_stroke_avgs = {
            stype: sum(scores) / len(scores) * 10
            for stype, scores in stroke_scores.items()
        }

        thirty_days_ago = (datetime.utcnow() - timedelta(days=30)).isoformat()
        history_result = (
            self.supabase.table("progress_snapshots")
            .select("*")
            .eq("user_id", user_id)
            .gte("snapshot_date", thirty_days_ago)
            .order("snapshot_date", desc=True)
            .execute()
        )
        history = history_result.data or []

        if len(history) >= 2:
            recent_avg = history[0].get("overall_score", 0)
            older_avg = history[-1].get("overall_score", 0)
            if recent_avg > older_avg + 2:
                trend = "improving"
            elif recent_avg < older_avg - 2:
                trend = "declining"
            else:
                trend = "stable"
        else:
            trend = "stable"

        overall = sum(session_stroke_avgs.values()) / max(len(session_stroke_avgs), 1)

        weakest = min(session_stroke_avgs, key=session_stroke_avgs.get, default="forehand")
        focus = f"Focus on improving your {weakest} this week"

        snapshot = {
            "user_id": user_id,
            "snapshot_date": datetime.utcnow().date().isoformat(),
            "overall_score": round(overall, 1),
            "forehand_score": round(session_stroke_avgs.get("forehand", 0), 1),
            "backhand_score": round(session_stroke_avgs.get("backhand", 0), 1),
            "serve_score": round(session_stroke_avgs.get("serve", 0), 1),
            "volley_score": round(session_stroke_avgs.get("volley", 0), 1),
            "trending_direction": trend,
        }

        self.supabase.table("progress_snapshots").upsert(snapshot).execute()
        return {**snapshot, "weekly_focus": focus}

    async def get_progress(self, user_id: str) -> dict:
        latest = (
            self.supabase.table("progress_snapshots")
            .select("*")
            .eq("user_id", user_id)
            .order("snapshot_date", desc=True)
            .limit(1)
            .execute()
        )

        ninety_days_ago = (datetime.utcnow() - timedelta(days=90)).isoformat()
        history = (
            self.supabase.table("progress_snapshots")
            .select("snapshot_date, overall_score")
            .eq("user_id", user_id)
            .gte("snapshot_date", ninety_days_ago)
            .order("snapshot_date")
            .execute()
        )

        week_ago = (datetime.utcnow() - timedelta(days=7)).isoformat()
        month_ago = (datetime.utcnow() - timedelta(days=30)).isoformat()

        weekly_sessions = (
            self.supabase.table("sessions")
            .select("id", count="exact")
            .eq("user_id", user_id)
            .eq("status", "ready")
            .gte("recorded_at", week_ago)
            .execute()
        )

        monthly_sessions = (
            self.supabase.table("sessions")
            .select("id", count="exact")
            .eq("user_id", user_id)
            .eq("status", "ready")
            .gte("recorded_at", month_ago)
            .execute()
        )

        snap = latest.data[0] if latest.data else {}
        weakest = "forehand"
        if snap:
            scores = {
                "forehand": snap.get("forehand_score", 0),
                "backhand": snap.get("backhand_score", 0),
                "serve": snap.get("serve_score", 0),
                "volley": snap.get("volley_score", 0),
            }
            weakest = min(scores, key=scores.get)

        return {
            "overall_score": snap.get("overall_score", 0),
            "forehand_score": snap.get("forehand_score", 0),
            "backhand_score": snap.get("backhand_score", 0),
            "serve_score": snap.get("serve_score", 0),
            "volley_score": snap.get("volley_score", 0),
            "trend": snap.get("trending_direction", "stable"),
            "weekly_focus": f"Focus on improving your {weakest} this week",
            "sessions_this_week": weekly_sessions.count or 0,
            "sessions_this_month": monthly_sessions.count or 0,
            "history": [
                {"date": h["snapshot_date"], "score": h["overall_score"]}
                for h in (history.data or [])
            ],
        }
```


## FILE: backend/main.py
```python
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.routes import sessions, progress, users, feedback

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(sessions.router, prefix="/api/v1")
app.include_router(progress.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(feedback.router, prefix="/api/v1")


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": settings.app_name}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=settings.debug)
```


## FILE: README.md
# TennisIQ

AI-powered tennis coaching through your iPhone camera. Record your sessions, get professional-level stroke analysis with visual overlays, and track your improvement over time.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   iPhone (On-Device)                 │
│                                                     │
│  Camera → Apple Vision (Pose) → Overlay Renderer    │
│             ↓                         ↑             │
│        Pose JSON + Key Frames    Feedback JSON      │
└──────────────┬──────────────────────┬───────────────┘
               ↓                      ↑
┌──────────────┴──────────────────────┴───────────────┐
│                  Cloud Backend                       │
│                                                     │
│  FastAPI → GPT-4o Vision → Structured Coaching JSON  │
│     ↕                                               │
│  Supabase (Postgres + Auth + Storage)               │
└─────────────────────────────────────────────────────┘
```

## Tech Stack

**iOS App**
- Swift 6 / SwiftUI
- AVFoundation (camera recording)
- Vision framework (on-device pose estimation)
- SwiftData (local persistence)
- StoreKit 2 (subscriptions)

**Backend**
- Python FastAPI
- OpenAI GPT-4o Vision API
- Supabase (Postgres, Auth, Storage)
- Deployed on Railway

## Project Structure

```
TennisIQ/
├── App/                    # App entry point, root navigation
├── Models/                 # SwiftData models + API types
├── Views/
│   ├── Record/             # Camera recording screen
│   ├── Sessions/           # Session list + Analysis Results (hero screen)
│   ├── Progress/           # Progress dashboard with charts
│   ├── Profile/            # Settings, subscription, theme picker
│   ├── Onboarding/         # 3-screen intro flow
│   └── Components/         # Shared UI components
├── ViewModels/             # MVVM view models
├── Services/
│   ├── CameraService       # AVFoundation camera management
│   ├── PoseEstimationService # Apple Vision pose extraction
│   ├── AnalysisAPIService  # Cloud API communication
│   ├── OverlayRenderer     # Skeleton + annotation drawing
│   ├── AuthService         # Sign in with Apple
│   └── SubscriptionService # StoreKit 2 purchases
├── Design/                 # 3 theme variants + design system
├── Utilities/              # Extensions, constants
└── Resources/              # Entitlements, assets

backend/
├── main.py                 # FastAPI app entry point
├── app/
│   ├── config.py           # Environment settings
│   ├── models.py           # Pydantic request/response models
│   ├── routes/             # API endpoints
│   ├── services/           # LLM coaching + progress calculator
│   └── prompts/            # Tennis coaching system prompts
├── supabase_schema.sql     # Database schema
├── requirements.txt
└── Dockerfile
```

## Setup

### Prerequisites
- Xcode 15+
- Python 3.12+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Supabase account
- OpenAI API key
- Apple Developer account (for Sign in with Apple + StoreKit)

### iOS App
```bash
# Generate Xcode project
cd "Tennis IQ"
xcodegen generate

# Open in Xcode
open TennisIQ.xcodeproj

# Update constants in TennisIQ/Utilities/Constants.swift:
# - Supabase URL + anon key
# - RevenueCat API key
```

### Backend
```bash
cd backend
cp .env.example .env
# Fill in your API keys in .env

pip install -r requirements.txt
uvicorn main:app --reload
```

### Database
1. Create a Supabase project
2. Run `supabase_schema.sql` in the SQL Editor
3. Enable Apple Sign In provider in Authentication settings

## Design Themes

Three visual schemes are included for prototyping:

| Theme | Aesthetic | Base | Accent |
|-------|-----------|------|--------|
| Court Vision | Dark Athletic Precision | `#0A0A0F` | `#C8FF00` (lime) |
| Grand Slam | Light Luxury Editorial | `#FAF8F5` | `#1B4332` (green) |
| Rally | Bold Sport-Tech | `#0C1222` | `#FF5C5C` (coral) |

Switch themes in Profile > Design Theme.

## MVP Scope

**Included:**
- Single camera recording (tripod/fence setup)
- Core 4 strokes: Forehand, Backhand, Serve, Volley
- AI stroke mechanics analysis with visual overlays
- Tactical gameplay feedback
- Progress tracking over time
- Subscription billing

**Future:**
- Real-time AR feedback during recording
- Multi-camera angle support
- Android app
- Social features
- Coach marketplace

## FILE: project.yml
name: TennisIQ
options:
  bundleIdPrefix: com.tennisiq
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "15.0"
  groupSortPosition: top

settings:
  base:
    SWIFT_VERSION: "5.9"
    TARGETED_DEVICE_FAMILY: "1"
    INFOPLIST_KEY_NSCameraUsageDescription: "TennisIQ needs camera access to record your tennis sessions for analysis."
    INFOPLIST_KEY_NSMicrophoneUsageDescription: "TennisIQ uses the microphone to capture audio during your session."
    INFOPLIST_KEY_NSPhotoLibraryUsageDescription: "TennisIQ saves analyzed videos to your photo library."

targets:
  TennisIQ:
    type: application
    platform: iOS
    sources:
      - TennisIQ
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.tennisiq.app
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        CODE_SIGN_STYLE: Automatic
    entitlements:
      path: TennisIQ/Resources/TennisIQ.entitlements
    dependencies:
      - package: Supabase

packages:
  Supabase:
    url: https://github.com/supabase/supabase-swift
    from: "2.0.0"

## FILE: requirements.txt
fastapi==0.109.2
uvicorn[standard]==0.27.1
python-multipart==0.0.9
openai==1.12.0
supabase==2.3.4
pydantic==2.6.1
pydantic-settings==2.1.0
python-jose[cryptography]==3.3.0
httpx>=0.24,<0.26
Pillow==10.2.0
numpy==1.26.4
