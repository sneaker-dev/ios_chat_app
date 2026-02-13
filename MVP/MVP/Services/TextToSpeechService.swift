//
//  TextToSpeechService.swift
//  MVP
//
//  v2.0: Exact Android parity - pitch 1.35/0.75, rate 0.85/0.95,
//  gender-matched voice selection, completion callbacks, word-by-word sync

import Foundation
import AVFoundation

final class TextToSpeechService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    var onSpeakingStarted: (() -> Void)?
    var onSpeakingCompleted: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: String? = nil, preferMale: Bool? = nil, rate: Float? = nil, completion: (() -> Void)? = nil) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let lang = normalizeLocale(language ?? Locale.current.languageCode ?? "en")
        let voice = voiceForLanguage(lang, preferMale: preferMale)
        if voice == nil {
            #if DEBUG
            print("[MVP] TTS: No voice for '\(lang)'. Skipping.")
            #endif
            isSpeaking = false; completion?(); return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        let isFemale = preferMale == false
        let baseRate = AVSpeechUtteranceDefaultSpeechRate
        if let r = rate { utterance.rate = r }
        else if isFemale { utterance.rate = baseRate * 0.85 }
        else { utterance.rate = baseRate * 0.95 }
        utterance.volume = 1.0
        utterance.pitchMultiplier = isFemale ? 1.35 : 0.75
        isSpeaking = true
        speechCompletion = completion
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("[MVP] TTS audio session error: \(error)")
            #endif
        }
        synthesizer.speak(utterance)
    }

    func estimateSpeechDuration(text: String, isFemale: Bool) -> TimeInterval {
        let words = text.split(separator: " ").count
        let wpm: Double = isFemale ? 127.5 : 142.5
        return max(Double(words) / wpm * 60.0, 0.5)
    }

    func millisecondsPerWord(isFemale: Bool) -> Int {
        let wpm: Double = isFemale ? 127.5 : 142.5
        return Int(1000.0 / (wpm / 60.0))
    }

    private func normalizeLocale(_ code: String) -> String {
        switch code.lowercased() {
        case "iw": return "he"
        case "in": return "id"
        case "ji": return "yi"
        default: return code
        }
    }

    static func formatLocale(_ languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "en": return "en-US"
        case "es": return "es-ES"
        case "fr": return "fr-FR"
        case "de": return "de-DE"
        case "it": return "it-IT"
        case "pt": return "pt-BR"
        case "ja": return "ja-JP"
        case "ko": return "ko-KR"
        case "zh": return "zh-CN"
        case "ru": return "ru-RU"
        case "uk": return "uk-UA"
        case "ar": return "ar-SA"
        case "he", "iw": return "he-IL"
        case "hi": return "hi-IN"
        case "id", "in": return "id-ID"
        case "pl": return "pl-PL"
        case "nl": return "nl-NL"
        case "tr": return "tr-TR"
        case "th": return "th-TH"
        case "vi": return "vi-VN"
        case "sv": return "sv-SE"
        case "da": return "da-DK"
        case "fi": return "fi-FI"
        case "nb", "no": return "nb-NO"
        case "cs": return "cs-CZ"
        case "el": return "el-GR"
        case "ro": return "ro-RO"
        case "hu": return "hu-HU"
        default:
            return languageCode.contains("-") ? languageCode : languageCode
        }
    }

    private func voiceForLanguage(_ language: String, preferMale: Bool?) -> AVSpeechSynthesisVoice? {
        let lp = language.prefix(2).lowercased()
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.prefix(2).lowercased() == lp }
        if voices.isEmpty { return AVSpeechSynthesisVoice(language: language) }
        guard let prefer = preferMale else { return AVSpeechSynthesisVoice(language: language) ?? voices.first }
        if #available(iOS 15.0, *) {
            let g: AVSpeechSynthesisVoiceGender = prefer ? .male : .female
            if let m = voices.first(where: { $0.gender == g }) { return m }
        }
        return AVSpeechSynthesisVoice(language: language) ?? voices.first
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        speechCompletion?()
        speechCompletion = nil
    }

    private var speechCompletion: (() -> Void)?
}

extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in self?.isSpeaking = true; self?.onSpeakingStarted?() }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            let c = self?.speechCompletion; self?.speechCompletion = nil; c?()
            self?.onSpeakingCompleted?()
        }
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            let c = self?.speechCompletion; self?.speechCompletion = nil; c?()
            self?.onSpeakingCompleted?()
        }
    }
}
