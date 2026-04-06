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
    @Published var selectedStrokeID: UUID?

    let player: AVPlayer
    private let videoURL: URL
    private var timeObserverToken: Any?
    private var sortedFrames: [FramePoseData] = []
    private var strokeWindows: [(start: Double, end: Double)] = []
    private let maxTrajectoryPoints = 60
    private var rawTrajectoryBuffer: [CGPoint] = []
    private var previousSmoothedJoints: [String: (x: Double, y: Double)] = [:]
    private let smoothingFactor: Double = 0.35
    private var allStrokes: [StrokeAnalysisModel] = []

    init(url: URL) {
        self.videoURL = url
        self.player = AVPlayer(playerItem: AVPlayerItem(url: url))
    }

    func configure(frames: [FramePoseData], strokes: [StrokeAnalysisModel]) {
        sortedFrames = frames.sorted { $0.timestamp < $1.timestamp }
        allStrokes = strokes.sorted { $0.timestamp < $1.timestamp }
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

        // Auto-highlight the stroke pill closest to the current playback time
        if player.rate > 0, !allStrokes.isEmpty {
            let nearest = allStrokes.min { abs($0.timestamp - seconds) < abs($1.timestamp - seconds) }
            if let nearest, abs(nearest.timestamp - seconds) < 3.0, nearest.id != selectedStrokeID {
                selectedStrokeID = nearest.id
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

    func selectStroke(_ stroke: StrokeAnalysisModel) {
        selectedStrokeID = stroke.id
        // Seek to the start of the swing (ready position), not the contact point.
        // This lets the user watch the full stroke from preparation through follow-through.
        if let breakdown = stroke.phaseBreakdown,
           let readyDetail = breakdown.detail(for: .readyPosition) {
            seekTo(timestamp: max(0, readyDetail.timestamp - 0.3))
        } else {
            seekTo(timestamp: max(0, stroke.timestamp - 1.5))
        }
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
    @State private var showDrillPlan = false
    @State private var showShareCard = false
    @State private var activeSection: SectionJumpBar.SectionTab = .overview
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var subscriptionService: SubscriptionService
    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let theme = DesignSystem.current
    private let analytics = AnalyticsService.shared

    /// Resolved video URL for passing to child views
    private var resolvedVideoURL: URL? {
        guard let filename = session.videoLocalURL else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docs.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Sessions")
                            .font(AppFont.body(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .principal) {
                Text(session.recordedAt.formatted(.dateTime.month(.wide).day()))
                    .font(AppFont.body(size: 13, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if session.status != .failed && !viewModel.isLoading {
                    HStack(spacing: Spacing.sm) {
                        // Drill Plan button
                        NavigationLink(destination: DrillPlanView(session: session)) {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.tennis")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Drills")
                                    .font(AppFont.body(size: 13, weight: .medium))
                            }
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xxs)
                            .background(
                                Capsule()
                                    .fill(theme.accentMuted)
                            )
                        }

                        Button(action: shareAnalysis) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.textSecondary)
                        }
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
        .onChange(of: playback.selectedStrokeID) { _, newID in
            guard let newID,
                  newID != selectedStroke?.id,
                  let match = session.strokeAnalyses.first(where: { $0.id == newID })
            else { return }
            selectedStroke = match
        }
        .onDisappear {
            playback.cleanup()
        }
        .sheet(isPresented: $showShareCard) {
            SessionShareSheet(session: session)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(subscriptionService)
        }
        .onChange(of: viewModel.isLoading) { wasLoading, isLoading in
            if wasLoading && !isLoading && session.status != .failed {
                // Record usage + check paywall
                subscriptionService.recordAnalysisUsed()

                analytics.trackEvent(.analysisCompleted(
                    strokeCount: session.strokeAnalyses.count,
                    overallGrade: session.overallGrade ?? "N/A"
                ))

                // If the user just used their last free analysis, show paywall after a beat
                if subscriptionService.currentTier == .free && !subscriptionService.canAnalyze {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        analytics.trackEvent(.paywallTriggered(freeAnalysesUsed: subscriptionService.freeAnalysesUsed))
                        showPaywall = true
                    }
                } else if analytics.shouldShowFeedbackPrompt {
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
        showShareCard = true
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
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 0) {
                    // 1. Video player
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
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                        }

                        if showOverlay && !playback.smoothedJoints.isEmpty {
                            WireframeOverlayView(
                                joints: playback.smoothedJoints,
                                videoNaturalSize: playback.videoNaturalSize,
                                highlightedJoints: highlightedJointNames,
                                highlightAngles: selectedPhaseAngles
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: heroVideoHeight)
                    .background(DesignSystem.current.navBackground)
                    .clipped()

                    // 2. Stroke selector pills
                    StrokeSelectorRow(
                        strokes: session.strokeAnalyses,
                        selectedStroke: $selectedStroke,
                        onSelectStroke: { stroke in
                            selectedStroke = stroke
                            playback.selectStroke(stroke)
                        }
                    )

                    // 2c. Section Jump Bar
                    SectionJumpBar(activeTab: $activeSection) { tab in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            switch tab {
                            case .overview:
                                scrollProxy.scrollTo("section_overview", anchor: .top)
                            case .phases:
                                scrollProxy.scrollTo("section_phases", anchor: .top)
                            case .coaching:
                                scrollProxy.scrollTo("section_coaching", anchor: .top)
                            case .drills:
                                scrollProxy.scrollTo("section_drills", anchor: .top)
                            }
                        }
                    }

                    // --- Overview Section ---
                    VStack(spacing: 0) {
                        // 2b. Compact Session Summary
                        CompactSessionSummaryCard(
                            session: session,
                            thingsToWorkOn: selectedStroke?.analysisCategories?.filter { $0.status != .inZone }.count ?? 0
                        )

                        // 4. Key Fixes
                        if let stroke = selectedStroke {
                            KeyFixesCard(
                                stroke: stroke,
                                selectedPhase: $selectedPhase,
                                onScrollToPhases: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        scrollProxy.scrollTo("section_phases", anchor: .top)
                                    }
                                    if let phase = selectedPhase,
                                       let detail = stroke.phaseBreakdown?.detail(for: phase) {
                                        playback.seekTo(timestamp: detail.timestamp)
                                    }
                                }
                            )
                        }
                    }
                    .id("section_overview")

                    // --- Phases Section ---
                    VStack(spacing: 0) {
                        if let stroke = selectedStroke, let breakdown = stroke.phaseBreakdown {
                            PhaseTimelineStrip(
                                breakdown: breakdown,
                                selectedPhase: $selectedPhase,
                                onPhaseSelected: { phase in
                                    if let detail = breakdown.detail(for: phase) {
                                        playback.seekTo(timestamp: detail.timestamp)
                                    }
                                },
                                videoURL: resolvedVideoURL,
                                poseFrames: session.poseFrames
                            )

                        
                        }
                    }
                    .id("section_phases")

                    // --- Coaching Section ---
                    StrokeCardsSection(strokes: session.strokeAnalyses, videoURL: resolvedVideoURL, scrollToPhases: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo("section_phases", anchor: .top)
                        }
                    }, poseFrames: session.poseFrames)
                        .id("section_coaching")

                    // --- Drills / Tactical Notes ---
                    TacticalNotesCard(notes: session.tacticalNotes)
                        .id("section_drills")

                    // --- Drill Plan CTA ---
                    NavigationLink(destination: DrillPlanView(session: session)) {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "figure.tennis")
                                .font(.system(size: 18))
                                .foregroundStyle(theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Open Practice Plan")
                                    .font(AppFont.body(size: 15, weight: .semibold))
                                    .foregroundStyle(theme.textPrimary)
                                Text("Take today's drills to the court")
                                    .font(AppFont.body(size: 12))
                                    .foregroundStyle(theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .padding(Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .fill(theme.surfacePrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.lg)
                                        .strokeBorder(theme.accent.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var heroVideoHeight: CGFloat {
        UIScreen.main.bounds.height * 0.40
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
            SkeletonWaitView(
                phase: "Extracting poses...",
                progress: progress
            )

        case .sendingToAPI:
            SkeletonWaitView(
                phase: "Analyzing with AI...",
                progress: 1.0
            )

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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    @State private var showSpeedOptions = false

    var body: some View {
        VStack {
            topControls
            Spacer()
            bottomControls
        }
    }

    private var topControls: some View {
        HStack(alignment: .top) {
            if playback.isInStrokeWindow && playback.autoSlowEnabled {
                StrokeWindowBadge()
            }
            Spacer()
            overlayToggleButton
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.lg)
    }

    private var bottomControls: some View {
        HStack(alignment: .bottom) {
            PlayPauseButton(isPlaying: playback.isPlaying) {
                playback.togglePlayPause()
            }

            Spacer()

            HStack(spacing: Spacing.md) {
                speedMenu
                textToggleButton(title: "Path", isActive: showSwingPath) { showSwingPath.toggle() }
                textToggleButton(title: showOverlay ? "Overlay" : "Clean", isActive: showOverlay) { showOverlay.toggle() }
                AutoSlowToggle(
                    isEnabled: playback.autoSlowEnabled,
                    onToggle: { playback.autoSlowEnabled.toggle() }
                )
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
    }

    private var overlayToggleButton: some View {
        Button(action: { showOverlay.toggle() }) {
            Text(showOverlay ? "Overlay On" : "Clean View")
                .font(AppFont.body(size: 11, weight: .semibold))
                .foregroundStyle(showOverlay ? theme.textPrimary.opacity(0.95) : theme.textSecondary.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.navBackground.opacity(0.82))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var speedMenu: some View {
        Menu {
            Button("0.25x") { playback.setSpeed(0.25) }
            Button("0.5x") { playback.setSpeed(0.5) }
            Button("1x") { playback.setSpeed(1.0) }
        } label: {
            Text(speedLabel(playback.selectedSpeed))
                .font(AppFont.mono(size: 12, weight: .bold))
                .foregroundStyle(theme.textPrimary.opacity(0.92))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.navBackground.opacity(0.82))
                .clipShape(Capsule())
        }
    }

    private func textToggleButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.body(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? theme.textPrimary.opacity(0.96) : theme.textSecondary.opacity(0.88))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.navBackground.opacity(isActive ? 0.88 : 0.72))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func speedLabel(_ speed: Float) -> String {
        if speed == 1.0 { return "1x" }
        return String(format: "%.2gx", speed)
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
                        .foregroundStyle(selectedSpeed == speed ? theme.textOnAccent : theme.textSecondary.opacity(0.88))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(selectedSpeed == speed ? theme.accent : theme.navBackground.opacity(0.78))
                        )
                }
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(theme.navBackground.opacity(0.88))
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
            Image(systemName: isEnabled ? "slowmo" : "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isEnabled ? theme.textOnAccent : theme.textSecondary.opacity(0.88))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isEnabled ? theme.accent.opacity(0.85) : theme.navBackground.opacity(0.84))
                )
        }
        .accessibilityLabel(isEnabled ? "Auto slow motion on" : "Auto slow motion off")
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

// MARK: - Focus Insight Card (Collapsible Main Fix)

struct VideoFocusInsightCard: View {
    let selectedStroke: StrokeAnalysisModel?
    let selectedPhase: SwingPhase?
    let onJumpToFocus: () -> Void
    var onJumpToTimestamp: ((Double) -> Void)? = nil
    private let theme = DesignSystem.current

    @State private var isMainFixExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsible header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isMainFixExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("MAIN FIX")
                        .font(AppFont.body(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .tracking(1.2)

                    Text("—")
                        .font(AppFont.body(size: 11))
                        .foregroundStyle(theme.textTertiary)

                    Text(primaryTitle)
                        .font(AppFont.body(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(isMainFixExpanded ? 180 : 0))
                }
                .padding(Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content: full rationale with highlighted spans
            if isMainFixExpanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if let text = fullRationale, !text.isEmpty {
                        buildAnnotatedText(text)
                            .font(AppFont.body(size: 14))
                            .foregroundStyle(theme.textSecondary)
                            .lineSpacing(3)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
    }

    private var primaryTitle: String {
        if let phase = selectedPhase {
            return phase.displayName + " Focus"
        }
        if let stroke = selectedStroke {
            return stroke.strokeType.displayName + " Focus"
        }
        return "Select a rep"
    }

    private var fullRationale: String? {
        if let phase = selectedPhase,
           let stroke = selectedStroke,
           let detail = stroke.phaseBreakdown?.detail(for: phase) {
            return detail.improveCue ?? detail.note
        }
        return selectedStroke?.gradingRationale ?? selectedStroke?.nextRepsPlan
    }

    // MARK: - Annotated text with highlighted timestamps and angles

    /// Builds a Text view with timestamps and angle measurements highlighted
    private func buildAnnotatedText(_ text: String) -> Text {
        let pattern = #"(\d+\.?\d*)\s*(seconds?|s\b)|(\d+)\s*°|(\d+)\s*degrees"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return Text(text)
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        guard !matches.isEmpty else {
            return Text(text)
        }

        var result = Text("")
        var lastEnd = 0

        for match in matches {
            let matchRange = match.range

            // Add plain text before this match
            if matchRange.location > lastEnd {
                let plainRange = NSRange(location: lastEnd, length: matchRange.location - lastEnd)
                let plainText = nsText.substring(with: plainRange)
                result = result + Text(plainText)
            }

            let matchedText = nsText.substring(with: matchRange)

            // Check if this is a timestamp (has seconds/s suffix)
            let isTimestamp = match.range(at: 1).location != NSNotFound || match.range(at: 2).location != NSNotFound

            if isTimestamp {
                // Highlighted timestamp — white + underline
                result = result + Text(matchedText)
                    .foregroundColor(.white)
                    .underline(true, color: .white.opacity(0.4))
            } else {
                // Angle measurement — accent color
                result = result + Text(matchedText)
                    .foregroundColor(theme.accent)
                    .bold()
            }

            lastEnd = matchRange.location + matchRange.length
        }

        // Remaining text
        if lastEnd < nsText.length {
            let remaining = nsText.substring(from: lastEnd)
            result = result + Text(remaining)
        }

        return result
    }
}

// MARK: - Stroke Selector Row (Pill Buttons)

struct StrokeSelectorRow: View {
    let strokes: [StrokeAnalysisModel]
    @Binding var selectedStroke: StrokeAnalysisModel?
    let onSelectStroke: (StrokeAnalysisModel) -> Void
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private let darkGreen = Color(red: 13/255, green: 40/255, blue: 24/255) // #0D2818

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(strokes) { stroke in
                        let isSelected = selectedStroke?.id == stroke.id

                        Button {
                            haptic.impactOccurred()
                            onSelectStroke(stroke)
                        } label: {
                            Text("\(stroke.strokeType.displayName) \(normalizedGrade(stroke.grade))")
                                .font(AppFont.body(size: 14, weight: .semibold))
                                .foregroundStyle(isSelected ? darkGreen : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.white : Color.clear)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .id(stroke.id)
                    }
                }
                .padding(.leading, Spacing.md)
                .padding(.trailing, Spacing.lg)
                .padding(.vertical, Spacing.sm)
            }
            .onChange(of: selectedStroke?.id) { _, newID in
                guard let newID else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Session Summary Card

struct SessionSummaryCard: View {
    let session: SessionModel
    var analysisCategories: [AnalysisCategory]? = nil
    var onSelectCategory: ((AnalysisCategory) -> Void)? = nil
    private let theme = DesignSystem.current

    private func numericScore(for grade: String) -> Double {
        switch normalizedGrade(grade) {
        case "A+": return 96; case "A": return 93; case "A-": return 90
        case "B+": return 87; case "B": return 84; case "B-": return 81
        case "C+": return 78; case "C": return 75; case "C-": return 72
        case "D+": return 69; case "D": return 66; case "D-": return 63
        case "F": return 55
        default: return 72
        }
    }

    /// Count of items needing work
    private var thingsToWorkOn: Int {
        analysisCategories?.filter { $0.status != .inZone }.count ?? 0
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            scoreSection
            if let categories = analysisCategories, !categories.isEmpty {
                reportCardSection(categories)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(theme.surfaceSecondary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .center, spacing: Spacing.md) {
                // Score ring — 80pt
                scoreRing

                // Score details on right
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        let score = numericScore(for: session.overallGrade ?? "C")
                        Text(String(format: "%.1f", score))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(theme.textPrimary)

                        Text(normalizedGrade(session.overallGrade ?? "--"))
                            .font(AppFont.body(size: 11, weight: .bold))
                            .foregroundStyle(theme.success)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.sm)
                                    .fill(theme.success.opacity(0.08))
                            )
                    }

                    Text("Session Score")
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            if thingsToWorkOn > 0 {
                Text("\(thingsToWorkOn) thing\(thingsToWorkOn == 1 ? "" : "s") to work on")
                    .font(AppFont.body(size: 13))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    private var scoreRing: some View {
        let score = numericScore(for: session.overallGrade ?? "C")
        let progress = score / 100.0

        return ZStack {
            Circle()
                .stroke(theme.surfaceSecondary, lineWidth: 7)
                .frame(width: 80, height: 80)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(theme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))

            Text(String(format: "%.1f", score))
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(theme.textPrimary)
        }
    }

    private func reportCardSection(_ categories: [AnalysisCategory]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 5) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
                Text("SWING ANALYSIS")
                    .font(AppFont.body(size: 11, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
                    .tracking(0.8)
            }

            ForEach(categories) { category in
                ReportCategoryRow(
                    category: category,
                    onTap: { onSelectCategory?(category) }
                )
            }
        }
    }
}

// MARK: - Compact Session Summary Card (score ring + grade + work-on count)

struct CompactSessionSummaryCard: View {
    let session: SessionModel
    let thingsToWorkOn: Int
    private let theme = DesignSystem.current

    private func numericScore(for grade: String) -> Double {
        switch normalizedGrade(grade) {
        case "A+": return 96; case "A": return 93; case "A-": return 90
        case "B+": return 87; case "B": return 84; case "B-": return 81
        case "C+": return 78; case "C": return 75; case "C-": return 72
        case "D+": return 69; case "D": return 66; case "D-": return 63
        case "F": return 55
        default: return 72
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Compact score ring — 60pt
            let score = numericScore(for: session.overallGrade ?? "C")
            let progress = score / 100.0
            ZStack {
                Circle()
                    .stroke(theme.surfaceSecondary, lineWidth: 5)
                    .frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                Text(String(format: "%.0f", score))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text(normalizedGrade(session.overallGrade ?? "--"))
                        .font(AppFont.body(size: 18, weight: .bold))
                        .foregroundStyle(theme.textPrimary)

                    Text("Session Score")
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textTertiary)
                }

                if thingsToWorkOn > 0 {
                    Text("\(thingsToWorkOn) thing\(thingsToWorkOn == 1 ? "" : "s") to work on")
                        .font(AppFont.body(size: 13))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(theme.surfaceSecondary, lineWidth: 1)
        )
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }
}

// MARK: - Stroke Cards Section (aggregated by type)

struct StrokeCardsSection: View {
    let strokes: [StrokeAnalysisModel]
    var videoURL: URL? = nil
    var scrollToPhases: (() -> Void)? = nil
    var poseFrames: [FramePoseData] = []

    private var summaries: [StrokeTypeSummary] {
        StrokeAggregator.aggregate(strokes)
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(summaries) { summary in
                StrokeTypeSummaryCard(
                    summary: summary,
                    videoURL: videoURL,
                    scrollToPhases: scrollToPhases,
                    poseFrames: poseFrames
                )
            }
        }
        .padding(Spacing.md)
    }
}

// MARK: - Stroke Type Summary Card

struct StrokeTypeSummaryCard: View {
    let summary: StrokeTypeSummary
    var videoURL: URL? = nil
    var scrollToPhases: (() -> Void)? = nil
    var poseFrames: [FramePoseData] = []
    @State private var showAllStrokes = false
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: stroke type + average score
            cardHeader

            Divider().foregroundStyle(theme.surfaceSecondary)

            VStack(alignment: .leading, spacing: Spacing.md) {
                // Hero coaching cue
                Text(summary.heroCoachingCue)
                    .font(AppFont.body(size: 16, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Skeleton correction visual from worst swing
                if let joints = summary.worstStroke.jointSnapshot, !joints.isEmpty,
                   let overlay = summary.worstStroke.overlayInstructions {
                    AngleCorrectionStrip(
                        joints: joints,
                        angleStrings: overlay.anglesToHighlight,
                        videoURL: videoURL,
                        timestamp: summary.worstStroke.timestamp,
                        phaseBreakdown: summary.worstStroke.phaseBreakdown,
                        poseFrames: poseFrames
                    )
                }

                // Best swing highlight
                if summary.strokes.count > 1 {
                    bestSwingHighlight
                }

                // One drill inline
                if let drill = summary.topDrill, !drill.isEmpty {
                    inlineDrill(drill)
                }

                // "See all N forehands →" disclosure
                if summary.strokes.count > 1 {
                    seeAllButton
                }
            }
            .padding(Spacing.md)

            // Expanded individual cards
            if showAllStrokes {
                Divider().foregroundStyle(theme.surfaceSecondary)
                VStack(spacing: Spacing.sm) {
                    ForEach(summary.strokes) { stroke in
                        CoachingCard(stroke: stroke, videoURL: videoURL, scrollToPhases: scrollToPhases, poseFrames: poseFrames)
                    }
                }
                .padding(Spacing.sm)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    private var cardHeader: some View {
        HStack {
            Image(systemName: summary.strokeType.icon)
                .font(.system(size: 16))
                .foregroundStyle(theme.accent)
                .frame(width: 32, height: 32)
                .background(theme.accentMuted)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))

            Text(summary.strokeType.displayName)
                .font(AppFont.body(size: 17, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            Text("· \(Int(summary.averageScore.rounded()))/100")
                .font(AppFont.mono(size: 15, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            Spacer()

            if let phaseName = summary.worstPhaseName {
                Text(phaseName)
                    .font(AppFont.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(theme.warning.opacity(0.12))
                    )
            }
        }
        .padding(Spacing.md)
    }

    private var bestSwingHighlight: some View {
        HStack(spacing: Spacing.sm) {
            Text("🌟")
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text("Your best \(summary.strokeType.displayName.lowercased())")
                    .font(AppFont.body(size: 13, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)

                if let note = summary.bestStroke.gradingRationale {
                    Text(note.components(separatedBy: ".").first ?? note)
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                } else {
                    Text("Grade: \(summary.bestStroke.grade.uppercased()) at \(String(format: "%.1fs", summary.bestStroke.timestamp))")
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Spacer()

            GradeBadge(grade: summary.bestStroke.grade)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(theme.success.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .strokeBorder(theme.success.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func inlineDrill(_ drill: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 5) {
                Image(systemName: "figure.tennis")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.accent)
                Text("PRACTICE DRILL")
                    .font(AppFont.body(size: 11, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
                    .tracking(0.5)
            }

            Text(drill)
                .font(AppFont.body(size: 13))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(3)
                .lineLimit(4)

            // YouTube link: curated video or search fallback
            Button {
                let url = DrillVideoMatcher.youtubeURL(for: drill) ?? DrillVideoMatcher.youtubeSearchURL(for: drill)
                UIApplication.shared.open(url)
            } label: {
                drillLinkLabel(
                    title: DrillVideoMatcher.youtubeURL(for: drill) != nil ? "Watch Drill Demo" : "Search Drill on YouTube",
                    icon: DrillVideoMatcher.youtubeURL(for: drill) != nil ? "play.fill" : "magnifyingglass",
                    full: DrillVideoMatcher.youtubeURL(for: drill) != nil
                )
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(theme.accentMuted)
        )
    }

    private func drillLinkLabel(title: String, icon: String, full: Bool) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(title)
                .font(AppFont.body(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(theme.accent.opacity(full ? 1.0 : 0.7))
        )
    }

    private var seeAllButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showAllStrokes.toggle()
            }
        } label: {
            HStack(spacing: Spacing.xxs) {
                Text(showAllStrokes
                     ? "Hide individual \(summary.strokeType.displayName.lowercased())s"
                     : "See all \(summary.strokes.count) \(summary.strokeType.displayName.lowercased())s")
                    .font(AppFont.body(size: 14, weight: .medium))
                Image(systemName: showAllStrokes ? "chevron.up" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(theme.accent)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Coaching Card (Redesigned with 4 sections)

struct CoachingCard: View {
    let stroke: StrokeAnalysisModel
    var videoURL: URL? = nil
    var scrollToPhases: (() -> Void)? = nil
    var poseFrames: [FramePoseData] = []
    @State private var isExpanded = false
    @State private var showMechanics = false
    @State private var showDrill = false
    @State private var showSources = false
    @State private var isBookmarked = false
    @State private var showBookmarkConfirm = false
    @Environment(\.modelContext) private var modelContext
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

                // Bookmark button
                Button(action: bookmarkStroke) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isBookmarked ? theme.accent : theme.textTertiary)
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(Spacing.md)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if showBookmarkConfirm {
                Text("Saved to Progress ✓")
                    .font(AppFont.body(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.success))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .offset(y: -8)
            }
        }
    }

    private func bookmarkStroke() {
        guard !isBookmarked else { return }

        let insight = BookmarkedInsight(
            strokeType: stroke.strokeType,
            grade: stroke.grade,
            coachingText: stroke.gradingRationale ?? stroke.mechanics?.contactPoint?.note ?? "No details",
            keyAngles: stroke.overlayInstructions?.anglesToHighlight ?? [],
            jointSnapshotJSON: stroke.jointSnapshotJSON,
            sessionDate: stroke.session?.recordedAt ?? Date(),
            phaseName: nil
        )
        modelContext.insert(insight)
        try? modelContext.save()

        withAnimation(.spring(response: 0.3)) {
            isBookmarked = true
            showBookmarkConfirm = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showBookmarkConfirm = false }
        }
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Divider().foregroundStyle(theme.surfaceSecondary)

            // What to Fix — always visible
            WhatToFixSection(rationale: stroke.gradingRationale)

            // Visual Angle Corrections — animated skeleton on real video frame
            if let joints = stroke.jointSnapshot, !joints.isEmpty,
               let overlay = stroke.overlayInstructions {
                AngleCorrectionStrip(
                    joints: joints,
                    angleStrings: overlay.anglesToHighlight,
                    videoURL: videoURL,
                    timestamp: stroke.timestamp,
                    phaseBreakdown: stroke.phaseBreakdown,
                    poseFrames: poseFrames
                )
            }

            // Mechanics Breakdown — collapsed by default
            CollapsibleSection(title: "MECHANICS BREAKDOWN", icon: "gearshape.2", isExpanded: $showMechanics) {
                MechanicsBreakdownSection(mechanics: stroke.mechanics, compactMode: true, scrollToPhases: scrollToPhases)
            }

            // Practice Drill — collapsed by default
            CollapsibleSection(title: "PRACTICE DRILL", icon: "play.circle.fill", isExpanded: $showDrill) {
                DrillSection(plan: stroke.nextRepsPlan)
            }

            // Verified Sources — collapsed by default
            CollapsibleSection(title: "VERIFIED SOURCES", icon: "checkmark.seal", isExpanded: $showSources) {
                VerifiedSourcesSection(stroke: stroke)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.md)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Collapsible Section Wrapper

struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textTertiary)
                    Text(title)
                        .font(AppFont.body(size: 11, weight: .bold))
                        .foregroundStyle(theme.textTertiary)
                        .tracking(0.5)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, Spacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .padding(.top, Spacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Grade Badge

struct GradeBadge: View {
    let grade: String
    private let theme = DesignSystem.current

    var body: some View {
        VStack(spacing: 2) {
            Text(scoreLabel(for: grade))
                .font(AppFont.mono(size: 11, weight: .bold))
                .foregroundStyle(gradeColor)

            Text(coachVerdict(for: grade))
                .font(AppFont.body(size: 10, weight: .bold))
                .foregroundStyle(gradeColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minWidth: 72, minHeight: 40)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(gradeColor.opacity(0.12))
        )
    }

    private var gradeColor: Color {
        semanticGradeColor(for: grade, theme: theme)
    }
}

// MARK: - Section 1: What to Fix (replaces Grade Rationale)

struct WhatToFixSection: View {
    let rationale: String?
    private let theme = DesignSystem.current

    /// Split rationale into bullet points using sentence-boundary splitting
    /// that avoids breaking on decimals like "21.6s"
    private var bullets: [String] {
        guard let text = rationale, !text.isEmpty else { return [] }
        // Split on ". " followed by uppercase letter, or on ";" or newlines
        let pattern = #"\.\s+(?=[A-Z])|;\s*|\n+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [text]
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        var parts: [String] = []
        var lastEnd = 0
        for match in matches {
            let range = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            let part = nsText.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            if !part.isEmpty { parts.append(part) }
            lastEnd = match.range.location + match.range.length
        }
        // Remaining text
        if lastEnd < nsText.length {
            let remaining = nsText.substring(from: lastEnd).trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty { parts.append(remaining) }
        }
        return Array(parts.prefix(3))
    }

    var body: some View {
        if !bullets.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SectionLabel(icon: "exclamationmark.triangle", title: "WHAT TO FIX")

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                        HStack(alignment: .top, spacing: Spacing.xs) {
                            Circle()
                                .fill(theme.warning)
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)

                            Text(bullet)
                                .font(AppFont.body(size: 13))
                                .foregroundStyle(theme.textPrimary)
                                .lineSpacing(3)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Section 2: Mechanics Breakdown

struct MechanicsBreakdownSection: View {
    let mechanics: StrokeMechanics?
    var compactMode: Bool = false
    var scrollToPhases: (() -> Void)? = nil
    private let theme = DesignSystem.current

    var body: some View {
        if let mechanics {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                mechanicsList(mechanics)

                // "See phase details" link when in compact mode
                if compactMode, let scrollToPhases {
                    Button(action: scrollToPhases) {
                        HStack(spacing: Spacing.xxs) {
                            Text("See phase details")
                                .font(AppFont.body(size: 13, weight: .medium))
                            Image(systemName: "arrow.up")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Spacing.xxs)
                }
            }
        }
    }

    @ViewBuilder
    private func mechanicsList(_ m: StrokeMechanics) -> some View {
        if let d = m.backswing { ExpandableMechanicRow(name: "Backswing", detail: d, compactMode: compactMode) }
        if let d = m.contactPoint { ExpandableMechanicRow(name: "Contact Point", detail: d, compactMode: compactMode) }
        if let d = m.followThrough { ExpandableMechanicRow(name: "Follow-Through", detail: d, compactMode: compactMode) }
        if let d = m.stance { ExpandableMechanicRow(name: "Stance", detail: d, compactMode: compactMode) }
        if let d = m.toss { ExpandableMechanicRow(name: "Toss", detail: d, compactMode: compactMode) }
    }
}

// MARK: - Expandable Mechanic Row

struct ExpandableMechanicRow: View {
    let name: String
    let detail: MechanicDetail
    var compactMode: Bool = false
    @State private var isExpanded = false
    @State private var showingSheet = false
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mechanicHeader
            if !compactMode && isExpanded {
                mechanicDetails
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.sm)
                .fill(theme.surfaceSecondary)
        )
        // In compact mode, show a sheet with the full detail on tap
        .sheet(isPresented: $showingSheet) {
            MechanicDetailSheet(name: name, detail: detail)
        }
    }

    private var mechanicHeader: some View {
        Button(action: {
            if compactMode {
                showingSheet = true
            } else {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            }
        }) {
            HStack {
                Text(name)
                    .font(AppFont.body(size: 13, weight: .medium))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                ScoreBar(score: detail.score)

                if !compactMode {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
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

// MARK: - Mechanic Detail Sheet (shown when tapping a grade in compact mode)

struct MechanicDetailSheet: View {
    let name: String
    let detail: MechanicDetail
    @Environment(\.dismiss) private var dismiss
    private let theme = DesignSystem.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    // Score header
                    HStack(spacing: Spacing.md) {
                        ScoreBar(score: detail.score)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(AppFont.body(size: 18, weight: .bold))
                                .foregroundStyle(theme.textPrimary)
                            Text(scoreLabel(detail.score))
                                .font(AppFont.body(size: 13))
                                .foregroundStyle(scoreColor(detail.score))
                        }
                        Spacer()
                    }
                    .padding(Spacing.md)
                    .background(RoundedRectangle(cornerRadius: Radius.md).fill(theme.surfaceSecondary))

                    // Analysis note
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Label("Analysis", systemImage: "text.magnifyingglass")
                            .font(AppFont.body(size: 12, weight: .bold))
                            .foregroundStyle(theme.textTertiary)
                        Text(detail.note)
                            .font(AppFont.body(size: 14))
                            .foregroundStyle(theme.textPrimary)
                            .lineSpacing(3)
                    }
                    .padding(Spacing.md)
                    .background(RoundedRectangle(cornerRadius: Radius.md).fill(theme.surfaceSecondary))

                    // Why this score
                    if let why = detail.whyScore, !why.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Label("Why this score", systemImage: "questionmark.circle")
                                .font(AppFont.body(size: 12, weight: .bold))
                                .foregroundStyle(theme.textTertiary)
                            Text(why)
                                .font(AppFont.body(size: 14))
                                .foregroundStyle(theme.textPrimary)
                                .lineSpacing(3)
                        }
                        .padding(Spacing.md)
                        .background(RoundedRectangle(cornerRadius: Radius.md).fill(theme.surfaceSecondary))
                    }

                    // Coaching cue
                    if let cue = detail.improveCue, !cue.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Label("Coaching Cue", systemImage: "quote.bubble")
                                .font(AppFont.body(size: 12, weight: .bold))
                                .foregroundStyle(theme.accent)
                            Text(cue)
                                .font(AppFont.body(size: 14))
                                .foregroundStyle(theme.textPrimary)
                                .lineSpacing(3)
                        }
                        .padding(Spacing.md)
                        .background(RoundedRectangle(cornerRadius: Radius.md).fill(theme.accentMuted))
                    }

                    // Drill
                    if let drill = detail.drill, !drill.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Label("Practice Drill", systemImage: "figure.tennis")
                                .font(AppFont.body(size: 12, weight: .bold))
                                .foregroundStyle(theme.accentSecondary)
                            Text(drill)
                                .font(AppFont.body(size: 14))
                                .foregroundStyle(theme.textPrimary)
                                .lineSpacing(3)
                        }
                        .padding(Spacing.md)
                        .background(RoundedRectangle(cornerRadius: Radius.md).fill(theme.surfaceSecondary))
                    }
                }
                .padding(Spacing.md)
            }
            .background(theme.background)
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.accent)
                }
            }
        }
    }

    private func scoreLabel(_ score: Int) -> String {
        switch score {
        case 8...10: return "Strong"
        case 6...7: return "Solid"
        case 4...5: return "Developing"
        case 1...3: return "Needs Work"
        default: return "Score: \(score)/10"
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 7...10: return theme.success
        case 4...6: return theme.warning
        default: return theme.error
        }
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

// MARK: - Section 3: Drill Section (card-within-card with green tint)

struct DrillSection: View {
    let plan: String?
    private let theme = DesignSystem.current

    /// Parse plan text into numbered steps
    private var steps: [(number: Int, text: String, duration: String?)] {
        guard let text = plan, !text.isEmpty else { return [] }
        let lines = text.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.enumerated().map { index, line in
            // Try to extract duration (e.g., "5 min", "10 min")
            var duration: String? = nil
            if let dRange = line.range(of: #"\d+\s*min"#, options: .regularExpression) {
                duration = String(line[dRange])
            }
            // Clean up numbered prefix
            let cleaned = line.replacingOccurrences(
                of: #"^\d+[\.\)]\s*"#,
                with: "",
                options: .regularExpression
            )
            return (index + 1, cleaned, duration)
        }
    }

    var body: some View {
        if let text = plan, !text.isEmpty {
            // Note: No header here — DrillSection is always wrapped in CollapsibleSection
            // which already shows the "PRACTICE DRILL" title. Adding it here caused a duplicate.
            VStack(alignment: .leading, spacing: Spacing.xs) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if !steps.isEmpty {
                        ForEach(steps, id: \.number) { step in
                            HStack(alignment: .center, spacing: Spacing.sm) {
                                // Step number circle
                                ZStack {
                                    Circle()
                                        .fill(theme.accent)
                                        .frame(width: 24, height: 24)
                                    Text("\(step.number)")
                                        .font(AppFont.body(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }

                                Text(step.text)
                                    .font(AppFont.body(size: 13))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineSpacing(2)

                                Spacer()

                                if let dur = step.duration {
                                    Text(dur)
                                        .font(AppFont.mono(size: 11))
                                        .foregroundStyle(theme.textTertiary)
                                }
                            }
                            .padding(.vertical, Spacing.xxs)

                            if step.number < steps.count {
                                Divider()
                                    .foregroundStyle(theme.accent.opacity(0.08))
                            }
                        }
                    } else {
                        // Fallback: show as paragraph
                        Text(text)
                            .font(AppFont.body(size: 13))
                            .foregroundStyle(theme.textPrimary)
                            .lineSpacing(3)
                    }

                    // Watch Demo — button opens YouTube directly to avoid tap swallowing
                    Button {
                        let url = DrillVideoMatcher.youtubeURL(for: text) ?? DrillVideoMatcher.youtubeSearchURL(for: text)
                        UIApplication.shared.open(url)
                    } label: {
                        let hasCurated = DrillVideoMatcher.youtubeURL(for: text) != nil
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: hasCurated ? "play.fill" : "magnifyingglass")
                                .font(.system(size: 12))
                            Text(hasCurated ? "Watch Drill Demo" : "Search Drill on YouTube")
                                .font(AppFont.body(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(theme.accent.opacity(hasCurated ? 1.0 : 0.7))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(theme.accentMuted)
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

private func normalizedGrade(_ grade: String) -> String {
    grade.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
}

private func gradeRankValue(_ grade: String) -> Int {
    switch normalizedGrade(grade) {
    case "A+": return 1
    case "A": return 2
    case "A-": return 3
    case "B+": return 4
    case "B": return 5
    case "B-": return 6
    case "C+": return 7
    case "C": return 8
    case "C-": return 9
    case "D+": return 10
    case "D": return 11
    case "D-": return 12
    case "F": return 13
    default: return 99
    }
}

private func semanticGradeColor(for grade: String, theme: AppTheme) -> Color {
    switch normalizedGrade(grade).prefix(1) {
    case "A": return theme.success
    case "B": return Color(hex: "84CC16")
    case "C": return theme.warning
    case "D": return Color(hex: "F97316")
    case "F": return theme.error
    default: return theme.textTertiary
    }
}

private func coachVerdict(for grade: String) -> String {
    switch normalizedGrade(grade).prefix(1) {
    case "A": return "Strong rep"
    case "B": return "Getting closer"
    case "C": return "Needs work"
    case "D", "F": return "Priority fix"
    default: return "Unscored"
    }
}

private func scoreLabel(for grade: String) -> String {
    switch normalizedGrade(grade) {
    case "A+": return "96/100"
    case "A": return "93/100"
    case "A-": return "90/100"
    case "B+": return "87/100"
    case "B": return "84/100"
    case "B-": return "81/100"
    case "C+": return "78/100"
    case "C": return "75/100"
    case "C-": return "72/100"
    case "D+": return "69/100"
    case "D": return "66/100"
    case "D-": return "63/100"
    case "F": return "55/100"
    default: return "--"
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
    var videoURL: URL? = nil
    var poseFrames: [FramePoseData] = []
    private let theme = DesignSystem.current

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: 5) {
                    Image(systemName: "timeline.selection")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                    Text("PHASE BREAKDOWN")
                        .font(AppFont.body(size: 11, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                        .tracking(0.5)
                }
                .padding(.horizontal, Spacing.md)

                phaseTimeline
            }
            .padding(.vertical, Spacing.md)
            .background(theme.surfacePrimary)

            if let phase = selectedPhase, let detail = breakdown.detail(for: phase) {
                PhaseDetailCard(phase: phase, detail: detail, videoURL: videoURL, poseFrames: poseFrames)
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.sm)
                    .background(theme.surfacePrimary)
            }
        }
    }

    private var phaseTimeline: some View {
        ZStack(alignment: .top) {
            // Connecting line behind dots
            Rectangle()
                .fill(theme.surfaceSecondary)
                .frame(height: 1.5)
                .padding(.horizontal, Spacing.lg)
                .offset(y: 14)

            HStack(spacing: 0) {
                ForEach(breakdown.allPhases, id: \.0) { phase, detail in
                    phaseNode(phase: phase, detail: detail)
                }
            }
        }
        .padding(.horizontal, Spacing.xxs)
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
            VStack(spacing: Spacing.xxs) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(isSelected ? DesignSystem.current.navBackground : theme.surfacePrimary)
                        .frame(width: isSelected ? 32 : 28, height: isSelected ? 32 : 28)

                    Circle()
                        .stroke(isSelected ? DesignSystem.current.navBackground : borderColor(status), lineWidth: 2)
                        .frame(width: isSelected ? 32 : 28, height: isSelected ? 32 : 28)

                    Image(systemName: phase.icon)
                        .font(.system(size: isSelected ? 13 : 11, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : theme.textSecondary)
                }
                .shadow(color: isSelected ? theme.textPrimary.opacity(0.15) : .clear, radius: 8, y: 2)

                // Score badge below circle
                Text("\(score)")
                    .font(AppFont.mono(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? theme.textOnAccent : theme.textPrimary)

                // Full phase name
                Text(phase.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? theme.textOnAccent : theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 22, alignment: .top)
                    .textCase(.uppercase)
                    .tracking(0.3)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func borderColor(_ status: ZoneStatus) -> Color {
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
    var onTap: (() -> Void)? = nil
    private let theme = DesignSystem.current

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: Spacing.sm) {
                // Colored status dot
                Circle()
                    .fill(zoneColor)
                    .frame(width: 6, height: 6)

                // Icon in accent-tinted circle
                Image(systemName: categoryIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(theme.accentMuted))

                // Name + one-line insight
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(AppFont.body(size: 14, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    Text(oneLineInsight)
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(insightColor)
                        .lineLimit(1)
                        .lineSpacing(2)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.vertical, 10)
            .frame(minHeight: 56)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider().foregroundStyle(theme.surfaceSecondary)
        }
    }

    /// One-line insight: positive for in-zone, specific issue for warning/out-of-zone
    private var oneLineInsight: String {
        switch category.status {
        case .inZone:
            let positiveNote = category.subchecks.first?.result ?? category.description
            return "Looks great \u{2014} \(positiveNote.lowercased())"
        case .warning, .outOfZone:
            // Use the first subcheck result that indicates a problem, or the category description
            let issueCheck = category.subchecks.first(where: { $0.status != .inZone })
            return issueCheck?.result ?? category.description
        }
    }

    private var insightColor: Color {
        switch category.status {
        case .inZone: return theme.textTertiary
        case .warning, .outOfZone: return theme.textSecondary
        }
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
                            Image(systemName: pro.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(theme.accent)
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
                            .fill(theme.skeletonStroke)
                            .frame(width: 10, height: 10)
                            .shadow(color: .black.opacity(0.3), radius: 3)
                            .position(pos)
                    }
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
        let degrees = acos(cosAngle) * 180 / .pi
        // Clamp to 0-180 range — dot product angle is always in [0, 180]
        // but ensure no floating point edge cases produce negatives
        return max(0, min(180, degrees))
    }

    private func computeShoulderRotation(_ map: [String: JointData]) -> Double? {
        guard let ls = map["left_shoulder"], let rs = map["right_shoulder"] else { return nil }
        let dx = rs.x - ls.x
        let dy = rs.y - ls.y
        let angle = atan2(abs(dy), abs(dx)) * 180 / .pi
        // Clamp: shoulder rotation should be 0-90°, never negative
        return max(0, 90 - angle)
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
        // Vision returns normalized coords in the raw pixel buffer space
        // with a bottom-left origin (y points up). For portrait iPhone video,
        // the raw buffer is landscape (1920x1080) with a 90-degree rotation
        // applied on display. videoNaturalSize is the display size (e.g. 1080x1920).
        //
        // After the 90-degree rotation:
        //   - Vision's y axis maps to the horizontal (display x)
        //   - Vision's x axis maps to the vertical (display y), but inverted
        //     because Vision's origin is bottom-left while UIKit is top-left.
        let videoX = joint.y * videoNaturalSize.width
        let videoY = (1.0 - joint.x) * videoNaturalSize.height
        return CGPoint(
            x: videoX * crop.scale + crop.offsetX,
            y: videoY * crop.scale + crop.offsetY
        )
    }
}
