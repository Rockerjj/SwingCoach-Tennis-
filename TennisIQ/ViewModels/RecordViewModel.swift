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
