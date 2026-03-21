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
        // Ensure audio session allows speech output alongside camera recording
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .videoRecording,
                options: [.defaultToSpeaker, .allowBluetooth, .duckOthers]
            )
            try audioSession.setActive(true)
        } catch {
            print("Voice feedback audio session error: \(error)")
        }

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
