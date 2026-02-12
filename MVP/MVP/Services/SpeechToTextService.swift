//
//  SpeechToTextService.swift
//  MVP
//

import Foundation
import Speech
import AVFoundation

/// Local Speech-to-Text using system language. Open-source system APIs only.
final class SpeechToTextService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText: String = ""
    @Published var errorMessage: String?

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale.current)
    private var recordingCompletion: ((String?) -> Void)?
    /// Auto-stop recording after this much silence (no new speech results).
    private let silenceTimeout: TimeInterval = 2.0
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
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer not available"
            completion(nil)
            return
        }

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
        request.requiresOnDeviceRecognition = false

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

        scheduleSilenceTimeout()

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
                        self.errorMessage = error.localizedDescription
                    }
                    self.finishRecording(with: self.transcribedText.isEmpty ? nil : self.transcribedText)
                }
            }
        }
    }

    private func scheduleSilenceTimeout() {
        cancelSilenceTimeout()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self, self.isRecording else { return }
            DispatchQueue.main.async {
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
