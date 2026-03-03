import Foundation
import AVFoundation

/// Microsoft Azure Cognitive Services Text-to-Speech REST API service.
/// Splits long text into SSML chunks, synthesises each one, and plays them sequentially.
/// Mirrors the Android AzureTTSManager behaviour.
final class AzureTTSService: NSObject, AVAudioPlayerDelegate {
    static let shared = AzureTTSService()
    private override init() {}

    private let subscriptionKey = "7NW0GsaDRpwhcnFvroHLO7k343Zv3QiMtZsigwAuQ4O5xOVC4xnOJQQJ99CBACYeBjFXJ3w3AAAYACOGXZRW"
    private let region = "eastus"
    private var endpoint: String { "https://\(region).tts.speech.microsoft.com/cognitiveservices/v1" }
    private let maxChunkLength = 4000

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

    private func voiceName(language: String, isFemale: Bool) -> String {
        let lang = String(language.prefix(2)).lowercased()
        switch lang {
        case "en": return isFemale ? "en-US-JennyNeural" : "en-US-GuyNeural"
        case "he": return isFemale ? "he-IL-HilaNeural"  : "he-IL-AvriNeural"
        case "ru": return isFemale ? "ru-RU-SvetlanaNeural" : "ru-RU-DmitryNeural"
        case "fr": return isFemale ? "fr-FR-DeniseNeural" : "fr-FR-HenriNeural"
        case "es": return isFemale ? "es-ES-ElviraNeural" : "es-ES-AlvaroNeural"
        case "de": return isFemale ? "de-DE-KatjaNeural"  : "de-DE-ConradNeural"
        case "ja": return isFemale ? "ja-JP-NanamiNeural" : "ja-JP-KeitaNeural"
        case "ko": return isFemale ? "ko-KR-SunHiNeural"  : "ko-KR-InJoonNeural"
        case "zh": return isFemale ? "zh-CN-XiaoxiaoNeural" : "zh-CN-YunxiNeural"
        case "ar": return isFemale ? "ar-SA-ZariyahNeural" : "ar-SA-HamedNeural"
        case "it": return isFemale ? "it-IT-ElsaNeural"   : "it-IT-DiegoNeural"
        case "pt": return isFemale ? "pt-BR-FranciscaNeural" : "pt-BR-AntonioNeural"
        case "uk": return isFemale ? "uk-UA-PolinaNeural" : "uk-UA-OstapNeural"
        case "pl": return isFemale ? "pl-PL-AgnieszkaNeural" : "pl-PL-MarekNeural"
        case "nl": return isFemale ? "nl-NL-ColetteNeural" : "nl-NL-MaartenNeural"
        case "tr": return isFemale ? "tr-TR-EmelNeural"   : "tr-TR-AhmetNeural"
        case "hi": return isFemale ? "hi-IN-SwaraNeural"  : "hi-IN-MadhurNeural"
        case "th": return isFemale ? "th-TH-PremwadeeNeural" : "th-TH-NiwatNeural"
        case "vi": return isFemale ? "vi-VN-HoaiMyNeural" : "vi-VN-NamMinhNeural"
        case "sv": return isFemale ? "sv-SE-SofieNeural"  : "sv-SE-MattiasNeural"
        case "da": return isFemale ? "da-DK-ChristelNeural" : "da-DK-JeppeNeural"
        case "fi": return isFemale ? "fi-FI-NooraNeural"  : "fi-FI-HarriNeural"
        case "nb", "no": return isFemale ? "nb-NO-PernilleNeural" : "nb-NO-FinnNeural"
        case "cs": return isFemale ? "cs-CZ-VlastaNeural" : "cs-CZ-AntoninNeural"
        case "el": return isFemale ? "el-GR-AthinaNeural" : "el-GR-NestorasNeural"
        case "ro": return isFemale ? "ro-RO-AlinaNeural"  : "ro-RO-EmilNeural"
        case "hu": return isFemale ? "hu-HU-NoemiNeural"  : "hu-HU-TamasNeural"
        case "id": return isFemale ? "id-ID-GadisNeural"  : "id-ID-ArdiNeural"
        default:   return isFemale ? "en-US-JennyNeural"  : "en-US-GuyNeural"
        }
    }

    private func speakChunks(text: String, language: String, isFemale: Bool) async {
        let chunks = splitIntoChunks(text)
        let voice = voiceName(language: language, isFemale: isFemale)
        let gender = isFemale ? "Female" : "Male"

        for chunk in chunks {
            guard !Task.isCancelled else { return }
            var data: Data?
            for attempt in 1...2 {
                if let d = try? await synthesise(chunk: chunk, language: language,
                                                 voiceName: voice, gender: gender) {
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

    private func synthesise(chunk: String, language: String, voiceName: String, gender: String) async throws -> Data {
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        let escapedChunk = chunk
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let ssml = """
        <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='\(language)'>
            <voice name='\(voiceName)' xml:gender='\(gender)'>\(escapedChunk)</voice>
        </speak>
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(subscriptionKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.setValue("audio-16khz-128kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        request.httpBody = ssml.data(using: .utf8)
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard !data.isEmpty else { throw URLError(.cannotDecodeContentData) }
        return data
    }

    @MainActor
    private func playAudioData(_ data: Data) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
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
