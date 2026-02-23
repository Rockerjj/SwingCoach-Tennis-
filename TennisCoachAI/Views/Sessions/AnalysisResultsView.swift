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

    let player: AVPlayer
    private let videoURL: URL
    private var timeObserverToken: Any?
    private var sortedFrames: [FramePoseData] = []
    private var strokeWindows: [(start: Double, end: Double)] = []

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
        }

        let inWindow = strokeWindows.contains { seconds >= $0.start && seconds <= $0.end }
        if inWindow != isInStrokeWindow {
            isInStrokeWindow = inWindow
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
    @State private var selectedStroke: StrokeAnalysisModel?
    @State private var showFeedbackPrompt = false
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

    private var analysisContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                LiveVideoPlayerSection(
                    playback: playback,
                    showOverlay: $showOverlay,
                    hasVideo: session.videoLocalURL != nil
                )

                if showOverlay {
                    OverlayInfoBadges(selectedStroke: selectedStroke)
                }

                StrokeTimelineStrip(
                    strokes: session.strokeAnalyses,
                    selectedStroke: $selectedStroke
                )

                SessionSummaryCard(session: session)

                StrokeCardsSection(strokes: session.strokeAnalyses)

                TacticalNotesCard(notes: session.tacticalNotes)
            }
        }
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

                if showOverlay && !playback.currentJoints.isEmpty {
                    WireframeOverlayView(
                        joints: playback.currentJoints,
                        videoNaturalSize: playback.videoNaturalSize
                    )
                    .containerRelativeFrame(.vertical) { height, _ in
                        height * 0.62
                    }
                    .allowsHitTesting(false)
                }

                VideoControlsOverlay(playback: playback, showOverlay: $showOverlay)
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
    private let theme = DesignSystem.current

    var body: some View {
        VStack(spacing: Spacing.md) {
            headerRow
            if let priority = session.topPriority {
                priorityBanner(priority)
            }
        }
        .padding(Spacing.md)
        .background(theme.surfacePrimary)
        .padding(.top, 1)
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

// MARK: - Wireframe Overlay View

struct WireframeOverlayView: View {
    let joints: [JointData]
    let videoNaturalSize: CGSize
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
                        var p = Path()
                        p.move(to: ptA)
                        p.addLine(to: ptB)
                        context.stroke(
                            p,
                            with: .color(theme.trajectoryLine.opacity(0.9)),
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                        )
                    }
                }

                ForEach(bodyJoints, id: \.name) { j in
                    Circle()
                        .fill(theme.angleAnnotation)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.3), radius: 3)
                        .position(toScreen(j, crop: crop))
                }
            }
        }
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
