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

    func selectStroke(_ stroke: StrokeAnalysisModel) {
        selectedStrokeID = stroke.id
        seekTo(timestamp: stroke.timestamp)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(session.recordedAt.formatted(.dateTime.month(.wide).day()))
                    .font(AppFont.body(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            }
            ToolbarItem(placement: .topBarTrailing) {
                if session.status != .failed && !viewModel.isLoading {
                    Button(action: shareAnalysis) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
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
                .background(TenniqueNightTheme.navBackground)
                .ignoresSafeArea(edges: .top)
                .clipped()

                VideoFocusInsightCard(
                    selectedStroke: selectedStroke,
                    selectedPhase: selectedPhase,
                    onJumpToFocus: {
                        if let phase = selectedPhase,
                           let breakdown = selectedStroke?.phaseBreakdown,
                           let detail = breakdown.detail(for: phase) {
                            playback.seekTo(timestamp: detail.timestamp)
                        } else if let stroke = selectedStroke {
                            playback.selectStroke(stroke)
                        }
                    },
                    onJumpToTimestamp: { timestamp in
                        playback.seekTo(timestamp: timestamp)
                    }
                )

                StrokeTimelineStrip(
                    strokes: session.strokeAnalyses,
                    selectedStroke: $selectedStroke,
                    onSelectStroke: { stroke in
                        selectedStroke = stroke
                        playback.selectStroke(stroke)
                    }
                )

                // Hero Insight Card — top priorities above phase timeline
                if let stroke = selectedStroke {
                    HeroInsightCard(
                        stroke: stroke,
                        videoURL: resolvedVideoURL,
                        poseFrames: session.poseFrames
                    )
                }

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

                SessionSummaryCard(
                    session: session,
                    analysisCategories: selectedStroke?.analysisCategories,
                    onSelectCategory: { category in
                        if let phase = selectedStroke?.phaseBreakdown?.allPhases.first(where: {
                            ($0.0.displayName.localizedCaseInsensitiveContains(category.name)) ||
                            (category.name.localizedCaseInsensitiveContains($0.0.displayName))
                        })?.0 {
                            selectedPhase = phase
                            if let detail = selectedStroke?.phaseBreakdown?.detail(for: phase) {
                                playback.seekTo(timestamp: detail.timestamp)
                            }
                        }
                    }
                )

                StrokeCardsSection(strokes: session.strokeAnalyses)

                TacticalNotesCard(notes: session.tacticalNotes)
            }
        }
        // Pro Comparison removed — not functional yet
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
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height * 0.68)
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
            .frame(maxWidth: .infinity)
            .frame(height: UIScreen.main.bounds.height * 0.68)
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
                .foregroundStyle(.white.opacity(showOverlay ? 0.95 : 0.72))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.18))
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
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.18))
                .clipShape(Capsule())
        }
    }

    private func textToggleButton(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.body(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(isActive ? 0.96 : 0.72))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(isActive ? 0.22 : 0.14))
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
            Image(systemName: isEnabled ? "slowmo" : "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isEnabled ? theme.textOnAccent : .white.opacity(0.8))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isEnabled ? theme.accent.opacity(0.85) : Color.black.opacity(0.4))
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

// MARK: - Focus Insight Card

struct VideoFocusInsightCard: View {
    let selectedStroke: StrokeAnalysisModel?
    let selectedPhase: SwingPhase?
    let onJumpToFocus: () -> Void
    var onJumpToTimestamp: ((Double) -> Void)? = nil
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("MAIN FIX")
                    .font(AppFont.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .tracking(1.2)

                Spacer()

                Button(action: onJumpToFocus) {
                    Text("Jump to focus")
                        .font(AppFont.body(size: 11, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }

            Text(primaryTitle)
                .font(AppFont.body(size: 20, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            if let text = truncatedSubtitle {
                Text(text)
                    .font(AppFont.body(size: 14))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(2)
            }

            if !focusMetrics.isEmpty {
                HStack(spacing: Spacing.xs) {
                    ForEach(focusMetrics.prefix(2), id: \.self) { metric in
                        Text(metric)
                            .font(AppFont.mono(size: 11, weight: .medium))
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(theme.accentMuted)
                            )
                    }
                }
            }

            // KEY MOMENTS strip
            if !keyMoments.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("KEY MOMENTS")
                        .font(AppFont.body(size: 10, weight: .bold))
                        .foregroundStyle(theme.textTertiary)
                        .tracking(0.8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(Array(keyMoments.enumerated()), id: \.offset) { _, moment in
                                Button(action: {
                                    onJumpToTimestamp?(moment.timestamp)
                                }) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(moment.metric)
                                            .font(AppFont.mono(size: 11, weight: .semibold))
                                            .foregroundStyle(theme.accent)
                                        Text(String(format: "@ %.1fs", moment.timestamp))
                                            .font(AppFont.mono(size: 9))
                                            .foregroundStyle(theme.textTertiary)
                                    }
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: Radius.sm)
                                            .fill(theme.surfaceSecondary)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
    }

    private var primaryTitle: String {
        if let phase = selectedPhase {
            return phase.displayName
        }
        if let stroke = selectedStroke {
            return stroke.strokeType.displayName + " focus"
        }
        return "Select a rep to see the main coaching focus"
    }

    /// Truncate subtitle to 2-3 sentences max
    private var truncatedSubtitle: String? {
        guard let text = rawSubtitle, !text.isEmpty else { return nil }
        let sentences = text.components(separatedBy: ". ")
        if sentences.count <= 3 {
            return text
        }
        return sentences.prefix(3).joined(separator: ". ") + "..."
    }

    private var rawSubtitle: String? {
        if let phase = selectedPhase,
           let stroke = selectedStroke,
           let detail = stroke.phaseBreakdown?.detail(for: phase) {
            return detail.improveCue ?? detail.note
        }
        return selectedStroke?.gradingRationale ?? selectedStroke?.nextRepsPlan
    }

    private var focusMetrics: [String] {
        if let phase = selectedPhase,
           let stroke = selectedStroke,
           let detail = stroke.phaseBreakdown?.detail(for: phase) {
            return detail.keyAngles
        }
        return selectedStroke?.overlayInstructions?.anglesToHighlight ?? []
    }

    /// Key moments parsed from overlay instructions and phase timestamps
    private var keyMoments: [(metric: String, timestamp: Double)] {
        guard let stroke = selectedStroke else { return [] }
        var moments: [(String, Double)] = []

        // From anglesToHighlight + phase timestamps
        if let angles = stroke.overlayInstructions?.anglesToHighlight,
           let breakdown = stroke.phaseBreakdown {
            for angle in angles {
                // Find matching phase timestamp
                let timestamp: Double = breakdown.allPhases.compactMap { (_, detail) in
                    detail?.timestamp
                }.first ?? stroke.timestamp

                moments.append((angle, timestamp))
            }
        }

        // If we got angles from phases with specific timestamps
        if let breakdown = stroke.phaseBreakdown {
            for (_, detail) in breakdown.allPhases {
                guard let d = detail, d.status != .inZone else { continue }
                for angle in d.keyAngles {
                    if !moments.contains(where: { $0.0 == angle }) {
                        moments.append((angle, d.timestamp))
                    }
                }
            }
        }

        return Array(moments.prefix(8))
    }
}

// MARK: - Stroke Timeline Strip

struct StrokeTimelineStrip: View {
    let strokes: [StrokeAnalysisModel]
    @Binding var selectedStroke: StrokeAnalysisModel?
    let onSelectStroke: (StrokeAnalysisModel) -> Void
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("STROKE TIMELINE")
                    .font(AppFont.body(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)

                Spacer()

                Text(summaryText)
                    .font(AppFont.mono(size: 11, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, Spacing.md)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(strokes) { stroke in
                            StrokeTimelineMarker(
                                stroke: stroke,
                                isSelected: selectedStroke?.id == stroke.id,
                                onTap: {
                                    onSelectStroke(stroke)
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        proxy.scrollTo(stroke.id, anchor: .center)
                                    }
                                }
                            )
                            .id(stroke.id)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .onChange(of: selectedStroke?.id) { _, newID in
                    guard let newID else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
        .padding(.vertical, Spacing.md)
        .background(theme.surfacePrimary)
    }

    private var summaryText: String {
        guard !strokes.isEmpty else { return "0 strokes" }
        let grades = strokes.map(\.grade)
        let avg = dominantGrade(in: grades) ?? "--"
        let best = grades.min { gradeRankValue($0) < gradeRankValue($1) } ?? "--"
        return "\(strokes.count) strokes • Avg: \(coachVerdict(for: avg)) • Best: \(coachVerdict(for: best))"
    }
}

struct StrokeTimelineMarker: View {
    let stroke: StrokeAnalysisModel
    let isSelected: Bool
    let onTap: () -> Void
    private let theme = DesignSystem.current

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.xs) {
                Text(stroke.strokeType.displayName)
                    .font(AppFont.body(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .white : theme.textPrimary)
                    .lineLimit(1)

                Text(normalizedGrade(stroke.grade))
                    .font(AppFont.body(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : gradeColor)
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: 40)
            .background(
                Capsule()
                    .fill(isSelected ? theme.accent : theme.surfacePrimary)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? theme.accent : theme.surfaceSecondary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var gradeColor: Color {
        semanticGradeColor(for: stroke.grade, theme: theme)
    }
}

// MARK: - Session Summary Card

struct SessionSummaryCard: View {
    let session: SessionModel
    var analysisCategories: [AnalysisCategory]? = nil
    var onSelectCategory: ((AnalysisCategory) -> Void)? = nil
    private let theme = DesignSystem.current

    /// Mock score history for sparkline (until multi-session tracking)
    private var mockScoreHistory: [Double] {
        let current = numericScore(for: session.overallGrade ?? "C")
        return [
            max(50, current - 14),
            max(50, current - 10),
            max(50, current - 12),
            max(50, current - 7),
            max(50, current - 4.5),
            max(50, current - 6),
            max(50, current - 4.2),
            current
        ]
    }

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

                    // Trend
                    let prev = mockScoreHistory.dropLast().last ?? 0
                    let current = numericScore(for: session.overallGrade ?? "C")
                    if prev > 0 {
                        Text("\u{2191} from \(String(format: "%.1f", prev)) last session")
                            .font(AppFont.body(size: 12, weight: .semibold))
                            .foregroundStyle(current >= prev ? theme.success : theme.error)
                    }

                    // Sparkline
                    ScoreSparklineView(scores: mockScoreHistory, width: 160, height: 40)
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

            // What to Fix — bullet points with bold numbers
            WhatToFixSection(rationale: stroke.gradingRationale)

            MechanicsBreakdownSection(mechanics: stroke.mechanics)

            // Practice Drill — card-within-card
            DrillSection(plan: stroke.nextRepsPlan)

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
        VStack(spacing: 2) {
            Text(scoreLabel(for: grade))
                .font(AppFont.mono(size: 11, weight: .bold))
                .foregroundStyle(gradeColor)

            Text(coachVerdict(for: grade))
                .font(AppFont.body(size: 9, weight: .bold))
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

    /// Split rationale into bullet points
    private var bullets: [String] {
        guard let text = rationale, !text.isEmpty else { return [] }
        // Split on sentences or common delimiters
        let parts = text.components(separatedBy: CharacterSet(charactersIn: ".;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: 5) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.accent)
                    Text("PRACTICE DRILL")
                        .font(AppFont.body(size: 11, weight: .bold))
                        .foregroundStyle(theme.accent)
                        .tracking(0.5)
                }

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

                    // Watch Demo button (placeholder)
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("Watch Demo")
                            .font(AppFont.body(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(theme.accent)
                    )
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

private func dominantGrade(in grades: [String]) -> String? {
    guard !grades.isEmpty else { return nil }
    let grouped = Dictionary(grouping: grades, by: { normalizedGrade($0) })
    return grouped.max { lhs, rhs in
        if lhs.value.count == rhs.value.count {
            return gradeRankValue(lhs.key) > gradeRankValue(rhs.key)
        }
        return lhs.value.count < rhs.value.count
    }?.key
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
                        .fill(isSelected ? TenniqueNightTheme.navBackground : theme.surfacePrimary)
                        .frame(width: isSelected ? 32 : 28, height: isSelected ? 32 : 28)

                    Circle()
                        .stroke(isSelected ? TenniqueNightTheme.navBackground : borderColor(status), lineWidth: 2)
                        .frame(width: isSelected ? 32 : 28, height: isSelected ? 32 : 28)

                    Image(systemName: phase.icon)
                        .font(.system(size: isSelected ? 13 : 11, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : theme.textSecondary)
                }
                .shadow(color: isSelected ? theme.textPrimary.opacity(0.15) : .clear, radius: 8, y: 2)

                // Score badge below circle
                Text("\(score)")
                    .font(AppFont.mono(size: 9, weight: .bold))
                    .foregroundStyle(isSelected ? .white : theme.textPrimary)

                // Full phase name
                Text(phase.displayName)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(isSelected ? .white : theme.textTertiary)
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
