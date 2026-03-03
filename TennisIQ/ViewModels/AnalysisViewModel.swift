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
