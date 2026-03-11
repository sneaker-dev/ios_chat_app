import Foundation
import Speech
import AVFoundation

final class SpeechToTextService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText: String = ""
    @Published var errorMessage: String?

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale.current)
    private var recordingCompletion: ((String?) -> Void)?
    private let silenceTimeout: TimeInterval = 1.0
    private var silenceWorkItem: DispatchWorkItem?

    override init() {
        super.init()
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.requestMicrophonePermission(completion: completion)
                case .denied:
                    self?.errorMessage = "Speech recognition denied. Enable in Settings."
                    completion(false)
                case .restricted:
                    self?.errorMessage = "Speech recognition restricted"
                    completion(false)
                case .notDetermined:
                    self?.errorMessage = "Speech recognition not determined"
                    completion(false)
                @unknown default:
                    completion(false)
                }
            }
        }
    }

    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()
        if session.recordPermission == .granted {
            completion(true)
            return
        }
        session.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if !granted {
                    self?.errorMessage = "Microphone access denied. Enable in Settings."
                }
                completion(granted)
            }
        }
    }

    func startRecording(completion: @escaping (String?) -> Void) {
        guard let recognizer = speechRecognizer else {
            errorMessage = "Speech recognizer not available"
            completion(nil)
            return
        }
        let canUseOnDeviceRecognition: Bool
        if #available(iOS 13.0, *) {
            canUseOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        } else {
            canUseOnDeviceRecognition = false
        }
        if !recognizer.isAvailable && !canUseOnDeviceRecognition {
            errorMessage = "Speech recognizer not available"
            completion(nil)
            return
        }

        // Keep behavior close to current online flow, but force on-device STT in offline/air-gapped mode.
        checkPublicInternet { [weak self] hasPublicInternet in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let preferOnDevice = !hasPublicInternet
                self.beginRecognitionSession(
                    recognizer: recognizer,
                    canUseOnDeviceRecognition: canUseOnDeviceRecognition,
                    preferOnDevice: preferOnDevice,
                    completion: completion
                )
            }
        }
    }

    private func beginRecognitionSession(
        recognizer: SFSpeechRecognizer,
        canUseOnDeviceRecognition: Bool,
        preferOnDevice: Bool,
        completion: @escaping (String?) -> Void
    ) {
        recognitionTask?.cancel()
        recognitionTask = nil
        recordingCompletion = completion

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            recordingCompletion = nil
            completion(nil)
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            recordingCompletion = nil
            completion(nil)
            return
        }
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = preferOnDevice && canUseOnDeviceRecognition

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            errorMessage = "Microphone error: \(error.localizedDescription)"
            recordingCompletion = nil
            completion(nil)
            return
        }

        isRecording = true
        transcribedText = ""
        errorMessage = nil

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let result = result {
                    self.scheduleSilenceTimeout()
                    let best = result.bestTranscription.formattedString
                    self.transcribedText = best
                    if result.isFinal && !best.isEmpty {
                        self.cancelSilenceTimeout()
                        self.finishRecording(with: best)
                        return
                    }
                }
                if let error = error {
                    self.cancelSilenceTimeout()
                    let isCancelled = (error as NSError).code == 216
                    if !isCancelled {
                        self.errorMessage = self.resolveRecognitionError(
                            error,
                            usedOnDeviceRecognition: request.requiresOnDeviceRecognition,
                            hasTranscribedText: !self.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                    self.finishRecording(with: self.transcribedText.isEmpty ? nil : self.transcribedText)
                }
            }
        }
    }

    private func checkPublicInternet(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://www.apple.com/library/test/success.html") else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 1.5
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            guard error == nil else {
                completion(false)
                return
            }
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            completion((200...399).contains(statusCode))
        }
        task.resume()
    }

    private func scheduleSilenceTimeout() {
        cancelSilenceTimeout()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.isRecording else { return }
            DispatchQueue.main.async {
                self.recognitionRequest?.endAudio()
                let text = self.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                self.finishRecording(with: text.isEmpty ? nil : text)
            }
        }
        silenceWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + silenceTimeout, execute: item)
    }

    private func cancelSilenceTimeout() {
        silenceWorkItem?.cancel()
        silenceWorkItem = nil
    }

    func stopRecording() {
        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        finishRecording(with: text.isEmpty ? nil : text)
    }

    private func resolveRecognitionError(
        _ error: Error,
        usedOnDeviceRecognition: Bool,
        hasTranscribedText: Bool
    ) -> String {
        let message = error.localizedDescription
        if usedOnDeviceRecognition && !hasTranscribedText {
            let lower = message.lowercased()
            if lower.contains("no speech") || lower.contains("no match") {
                return "No speech detected. Please try again."
            }
            return "Offline voice recognition is not available."
        }
        return message
    }

    private func finishRecording(with text: String?) {
        guard isRecording else { return }
        cancelSilenceTimeout()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
        let completion = recordingCompletion
        recordingCompletion = nil
        DispatchQueue.main.async {
            completion?(text)
        }
    }
}
