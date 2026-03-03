import Foundation
import AVFoundation

/// Google Cloud Text-to-Speech REST API service.
/// Splits long text into chunks, synthesises each one via the REST API, and plays them sequentially.
/// Mirrors the Android CloudTTSManager behaviour.
final class CloudTTSService: NSObject, AVAudioPlayerDelegate {
    static let shared = CloudTTSService()
    private override init() {}

    private let apiKey  = "AIzaSyAoINxQ_SZUNdgaTvpbnhH3h08xpyl2dZE"
    private let endpoint = "https://texttospeech.googleapis.com/v1/text:synthesize"
    private let maxChunkLength = 4500

    private var player: AVAudioPlayer?
    private var currentTask: Task<Void, Never>?
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    var isSpeaking: Bool { player?.isPlaying == true }

    // MARK: - Public API

    func speak(text: String, language: String = "en-US", isFemale: Bool = true, completion: (() -> Void)? = nil) {
        stop()
        currentTask = Task { [weak self] in
            await self?.speakChunks(text: text, language: language, isFemale: isFemale)
            await MainActor.run { completion?() }
        }
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
        player?.stop()
        player = nil
        if let cont = playbackContinuation {
            playbackContinuation = nil
            cont.resume()
        }
    }

    // MARK: - Private

    private func splitIntoChunks(_ text: String) -> [String] {
        guard text.count > maxChunkLength else { return [text] }
        var chunks: [String] = []
        var remaining = text
        while remaining.count > maxChunkLength {
            let prefix = String(remaining.prefix(maxChunkLength))
            var splitAt = prefix.count
            if let idx = prefix.lastIndex(where: { ".!?\n".contains($0) }) {
                splitAt = prefix.distance(from: prefix.startIndex, to: idx) + 1
            }
            let splitIndex = remaining.index(remaining.startIndex, offsetBy: splitAt)
            chunks.append(String(remaining[..<splitIndex]).trimmingCharacters(in: .whitespaces))
            remaining = String(remaining[splitIndex...]).trimmingCharacters(in: .whitespaces)
        }
        if !remaining.isEmpty { chunks.append(remaining) }
        return chunks
    }

    private func voiceName(language: String, isFemale: Bool) -> String? {
        let lang = String(language.prefix(2)).lowercased()
        switch lang {
        case "en": return isFemale ? "en-US-Wavenet-F" : "en-US-Wavenet-D"
        case "he": return isFemale ? "he-IL-Wavenet-B" : "he-IL-Wavenet-A"
        case "ru": return isFemale ? "ru-RU-Wavenet-A" : "ru-RU-Wavenet-B"
        case "fr": return isFemale ? "fr-FR-Wavenet-A" : "fr-FR-Wavenet-B"
        case "es": return isFemale ? "es-ES-Wavenet-A" : "es-ES-Wavenet-B"
        case "de": return isFemale ? "de-DE-Wavenet-A" : "de-DE-Wavenet-B"
        case "ja": return isFemale ? "ja-JP-Wavenet-A" : "ja-JP-Wavenet-C"
        case "ko": return isFemale ? "ko-KR-Wavenet-A" : "ko-KR-Wavenet-C"
        case "zh": return isFemale ? "cmn-CN-Wavenet-A" : "cmn-CN-Wavenet-B"
        case "ar": return isFemale ? "ar-XA-Wavenet-A" : "ar-XA-Wavenet-B"
        case "it": return isFemale ? "it-IT-Wavenet-A" : "it-IT-Wavenet-C"
        case "pt": return isFemale ? "pt-BR-Wavenet-A" : "pt-BR-Wavenet-B"
        default:   return nil
        }
    }

    private func speakChunks(text: String, language: String, isFemale: Bool) async {
        let chunks = splitIntoChunks(text)
        let voice  = voiceName(language: language, isFemale: isFemale)
        let effectiveLang: String = {
            if let v = voice {
                let parts = v.split(separator: "-")
                if parts.count >= 2 { return "\(parts[0])-\(parts[1])" }
            }
            return language
        }()

        for chunk in chunks {
            guard !Task.isCancelled else { return }
            var data: Data?
            for attempt in 1...2 {
                if let d = try? await synthesise(chunk: chunk, language: effectiveLang,
                                                 voiceName: voice, isFemale: isFemale) {
                    data = d
                    break
                }
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled else { return }
                }
            }
            guard let audioData = data else { return }
            guard !Task.isCancelled else { return }
            await playAudioData(audioData)
            guard !Task.isCancelled else { return }
        }
    }

    private func synthesise(chunk: String, language: String, voiceName: String?,
                            isFemale: Bool) async throws -> Data {
        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else { throw URLError(.badURL) }

        var voiceDict: [String: Any] = [
            "languageCode": language,
            "ssmlGender": isFemale ? "FEMALE" : "MALE"
        ]
        if let name = voiceName { voiceDict["name"] = name }

        let body: [String: Any] = [
            "input": ["text": chunk],
            "voice": voiceDict,
            "audioConfig": ["audioEncoding": "MP3"]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audioBase64 = json["audioContent"] as? String,
              let audioData = Data(base64Encoded: audioBase64),
              !audioData.isEmpty
        else { throw URLError(.cannotDecodeContentData) }

        return audioData
    }

    @MainActor
    private func playAudioData(_ data: Data) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default,
                                                                options: [.duckOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                let ap = try AVAudioPlayer(data: data)
                ap.delegate = self
                playbackContinuation = cont
                player = ap
                ap.play()
            } catch {
                cont.resume()
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.player = nil
            let cont = self?.playbackContinuation
            self?.playbackContinuation = nil
            cont?.resume()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.player = nil
            let cont = self?.playbackContinuation
            self?.playbackContinuation = nil
            cont?.resume()
        }
    }
}
