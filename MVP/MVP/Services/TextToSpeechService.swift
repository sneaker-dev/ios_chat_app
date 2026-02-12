//
//  TextToSpeechService.swift
//  MVP
//
//  v2.0: Enhanced with gender-matched voice, female rate adjustment,
//  proper completion callbacks, and word-by-word sync support

import Foundation
import AVFoundation

/// Local Text-to-Speech using system language. Open-source system APIs only.
final class TextToSpeechService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    @Published var isSpeaking = false
    
    /// Callback when TTS starts speaking
    var onSpeakingStarted: (() -> Void)?
    /// Callback when TTS finishes speaking
    var onSpeakingCompleted: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks the given text in the system/dialog language.
    /// - Parameters:
    ///   - text: Text to speak
    ///   - language: Language code (e.g., "en", "he", "uk")
    ///   - preferMale: true for male avatar, false for female
    ///   - rate: Speech rate (nil = default; female avatars use 0.85x)
    ///   - completion: Called when speech finishes
    func speak(_ text: String, language: String? = nil, preferMale: Bool? = nil, rate: Float? = nil, completion: (() -> Void)? = nil) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let lang = normalizeLocale(language ?? Locale.current.languageCode ?? "en")
        let voice = voiceForLanguage(lang, preferMale: preferMale)
        if voice == nil {
            #if DEBUG
            print("[MVP] TTS: No voice for language '\(lang)' (common in Simulator). Skipping speech.")
            #endif
            isSpeaking = false
            completion?()
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        
        // v2.0: Female voice rate adjustment (matching Android 0.85f)
        let isFemale = preferMale == false
        let baseRate = AVSpeechUtteranceDefaultSpeechRate
        if let customRate = rate {
            utterance.rate = customRate
        } else if isFemale {
            utterance.rate = baseRate * 0.85  // Female speaks slightly slower
        } else {
            utterance.rate = baseRate * 0.95  // Male slightly slower than default
        }
        
        utterance.volume = 1.0
        utterance.pitchMultiplier = isFemale ? 1.1 : 0.9  // Slight pitch shift for gender
        
        isSpeaking = true
        speechCompletion = completion
        
        // Configure audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("[MVP] TTS: Audio session error: \(error)")
            #endif
        }
        
        synthesizer.speak(utterance)
    }
    
    /// Estimate speech duration for synchronization
    /// Based on word count and speech rate
    func estimateSpeechDuration(text: String, isFemale: Bool) -> TimeInterval {
        let words = text.split(separator: " ").count
        // Words per minute based on avatar gender (matching Android)
        let wordsPerMinute: Double = isFemale ? 127.5 : 142.5
        let duration = Double(words) / wordsPerMinute * 60.0
        return max(duration, 0.5) // Minimum 0.5 seconds
    }
    
    /// Calculate milliseconds per word for synchronized text display
    func millisecondsPerWord(isFemale: Bool) -> Int {
        let wordsPerMinute: Double = isFemale ? 127.5 : 142.5
        let wordsPerSecond = wordsPerMinute / 60.0
        return Int(1000.0 / wordsPerSecond)
    }

    /// Normalize locale codes (matching Android's Hebrew/Ukrainian fix)
    private func normalizeLocale(_ code: String) -> String {
        switch code.lowercased() {
        case "iw": return "he"       // Hebrew: legacy code
        case "in": return "id"       // Indonesian: legacy code
        case "ji": return "yi"       // Yiddish: legacy code
        default: return code
        }
    }
    
    /// Format locale for API (e.g., "en" → "en-US", "he" → "he-IL")
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
            if languageCode.contains("-") {
                return languageCode
            }
            return languageCode // Pass through as-is (let API handle it)
        }
    }

    /// Picks a voice for the language; if preferMale is true/false, prefers male/female when available (iOS 15+).
    private func voiceForLanguage(_ language: String, preferMale: Bool?) -> AVSpeechSynthesisVoice? {
        let langPrefix = language.prefix(2)
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix(langPrefix) || voice.language.prefix(2).lowercased() == langPrefix.lowercased()
        }
        if voices.isEmpty {
            return AVSpeechSynthesisVoice(language: language)
        }
        guard let prefer = preferMale else {
            return AVSpeechSynthesisVoice(language: language) ?? voices.first
        }
        if #available(iOS 15.0, *) {
            let gender: AVSpeechSynthesisVoiceGender = prefer ? .male : .female
            if let match = voices.first(where: { $0.gender == gender }) {
                return match
            }
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
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = true
            self?.onSpeakingStarted?()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            let completion = self?.speechCompletion
            self?.speechCompletion = nil
            completion?()
            self?.onSpeakingCompleted?()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            let completion = self?.speechCompletion
            self?.speechCompletion = nil
            completion?()
            self?.onSpeakingCompleted?()
        }
    }
}
