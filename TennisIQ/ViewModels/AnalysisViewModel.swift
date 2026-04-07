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

            // Check network before sending to API
            if !NetworkMonitor.shared.isConnected {
                await MainActor.run {
                    session.status = .processing // Keep as processing so it retries later
                    try? context.save()
                }
                throw AnalysisError.offline
            }

            await MainActor.run {
                poseProgress = 1.0
                analysisPhase = .sendingToAPI
                session.status = .analyzing
                try? context.save()
            }

            let sampledStrokes = selectRepresentativeStrokes(from: extraction.detectedStrokes)
            let sampledKeyFrames = filterKeyFrames(extraction.keyFrames, for: sampledStrokes)

            // Only send frames near sampled strokes to reduce payload size
            let relevantFrames = extraction.frames.filter { frame in
                sampledStrokes.contains { abs($0.contactTimestamp - frame.timestamp) < 2.0 }
            }

            let payload = SessionPosePayload(
                sessionID: session.id.uuidString,
                durationSeconds: session.durationSeconds,
                fps: AppConstants.Camera.processingFPS,
                frames: relevantFrames,
                keyFrameTimestamps: sampledKeyFrames.map(\.timestamp),
                skillLevel: UserDefaults.standard.string(forKey: "skillLevel") ?? "beginner",
                handedness: Handedness.current.rawValue,
                detectedStrokes: sampledStrokes
            )

            let authToken = AuthService().authToken

            // Extract short video clips around each stroke for Gemini video analysis
            var strokeClipURLs: [(timestamp: Double, url: URL)] = []
            if let url = videoURL {
                let clips = try await poseService.extractStrokeClips(
                    from: url,
                    strokes: sampledStrokes
                )
                strokeClipURLs = clips.map { (timestamp: $0.timestamp, url: $0.url) }
            }

            let response = try await apiService.analyzeSession(
                posePayload: payload,
                keyFrameImages: sampledKeyFrames.map { (timestamp: $0.timestamp, image: $0.image) },
                strokeClips: strokeClipURLs,
                authToken: authToken
            )

            applyResults(response, extractionFrames: extraction.frames, to: session, context: context)

            // Clean up temp files now that they've been sent to the API
            extraction.cleanupTempFiles()
            if !strokeClipURLs.isEmpty {
                let clips = strokeClipURLs.map { PoseEstimationService.StrokeClip(timestamp: $0.timestamp, url: $0.url) }
                poseService.cleanupClips(clips)
            }

            // Sync progress data so the dashboard updates immediately
            let progressVM = ProgressViewModel()
            await progressVM.sync(context: context)

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

    // MARK: - Representative Stroke Sampling

    /// For longer sessions with many strokes, pick one representative per stroke type.
    /// Selects the stroke with the most visible (high-confidence) angle measurements,
    /// so GPT gets the clearest data to work with.
    private func selectRepresentativeStrokes(from strokes: [DetectedStroke], maxPerType: Int = 2) -> [DetectedStroke] {
        guard strokes.count > 4 else { return strokes }

        var grouped: [String: [DetectedStroke]] = [:]
        for stroke in strokes {
            grouped[stroke.type, default: []].append(stroke)
        }

        var selected: [DetectedStroke] = []
        for (_, typeStrokes) in grouped {
            let ranked = typeStrokes.sorted { a, b in
                visibleAngleCount(a) > visibleAngleCount(b)
            }
            selected.append(contentsOf: ranked.prefix(maxPerType))
        }

        return selected.sorted { $0.contactTimestamp < $1.contactTimestamp }
    }

    private func visibleAngleCount(_ stroke: DetectedStroke) -> Int {
        stroke.phases.values.reduce(0) { count, phase in
            count + phase.angles.values.filter(\.visible).count
        }
    }

    /// Keep only key frames that are near the selected strokes' contact points.
    private func filterKeyFrames(
        _ keyFrames: [(timestamp: Double, image: UIImage)],
        for strokes: [DetectedStroke]
    ) -> [(timestamp: Double, image: UIImage)] {
        let contactTimes = strokes.map(\.contactTimestamp)
        let relevant = keyFrames.filter { kf in
            contactTimes.contains { abs($0 - kf.timestamp) < 1.5 }
        }
        if relevant.count >= 2 { return Array(relevant.prefix(6)) }
        return Array(keyFrames.prefix(6))
    }

    enum AnalysisError: LocalizedError {
        case videoNotFound
        case offline

        var errorDescription: String? {
            switch self {
            case .videoNotFound: return "Recording video file not found."
            case .offline: return "No internet connection. Your session is saved — analysis will run when you're back online."
            }
        }
    }
}
