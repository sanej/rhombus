import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published var transcript = ""
    @Published var isListening = false
    @Published var level: Float = 0

    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onFinal: ((String) -> Void)?

    func toggle(onFinal: @escaping (String) -> Void) {
        if isListening { stop(); return }
        SFSpeechRecognizer.requestAuthorization { status in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                Task { @MainActor in
                    if status == .authorized && granted { self.start(onFinal: onFinal) }
                    else { self.transcript = "Enable microphone and speech access in Settings." }
                }
            }
        }
    }

    private func start(onFinal: @escaping (String) -> Void) {
        self.onFinal = onFinal
        transcript = ""
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if recognizer?.supportsOnDeviceRecognition == true { req.requiresOnDeviceRecognition = true }
            request = req
            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { [weak self] buf, _ in
                req.append(buf)
                let data = buf.floatChannelData?[0]
                let n = Int(buf.frameLength)
                var sum: Float = 0
                if let data { for i in 0..<n { sum += data[i] * data[i] } }
                let rms = n > 0 ? sqrt(sum / Float(n)) : 0
                Task { @MainActor in self?.level = min(1, rms * 8) }
            }
            engine.prepare()
            try engine.start()
            isListening = true
            task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result { self.transcript = result.bestTranscription.formattedString }
                    if error != nil || result?.isFinal == true { self.finish() }
                }
            }
        } catch {
            transcript = "Couldn't start listening."
            stop()
        }
    }

    func stop() {
        request?.endAudio()
        if engine.isRunning { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        isListening = false
        level = 0
    }

    private func finish() {
        let text = transcript
        let cb = onFinal
        onFinal = nil
        task?.cancel(); task = nil; request = nil
        stop()
        if !text.isEmpty { cb?(text) }
    }
}
