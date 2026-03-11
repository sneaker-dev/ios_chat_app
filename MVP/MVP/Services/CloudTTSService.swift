import Foundation
import AVFoundation

/// Google Cloud Text-to-Speech REST API service.
/// Inherits chunking, playback, and lifecycle management from BaseTTSService.
final class CloudTTSService: BaseTTSService {
    static let shared = CloudTTSService()
    private override init() { super.init() }

    private let apiKey   = "AIzaSyAoINxQ_SZUNdgaTvpbnhH3h08xpyl2dZE"
    private let endpoint = "https://texttospeech.googleapis.com/v1/text:synthesize"

    override var maxChunkLength: Int { 4500 }

    // MARK: - BaseTTSService

    override func synthesiseChunk(_ chunk: String, language: String, isFemale: Bool) async throws -> Data {
        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else { throw URLError(.badURL) }

        let voice = voiceName(language: language, isFemale: isFemale)
        let effectiveLang: String = {
            if let v = voice {
                let parts = v.split(separator: "-")
                if parts.count >= 2 { return "\(parts[0])-\(parts[1])" }
            }
            return language
        }()

        var voiceDict: [String: Any] = [
            "languageCode": effectiveLang,
            "ssmlGender": isFemale ? "FEMALE" : "MALE"
        ]
        if let name = voice { voiceDict["name"] = name }

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

    // MARK: - Voice selection

    private func voiceName(language: String, isFemale: Bool) -> String? {
        let lang = String(language.prefix(2)).lowercased()
        switch lang {
        case "en": return isFemale ? "en-US-Wavenet-F"  : "en-US-Wavenet-D"
        case "he": return isFemale ? "he-IL-Wavenet-B"  : "he-IL-Wavenet-A"
        case "ru": return isFemale ? "ru-RU-Wavenet-A"  : "ru-RU-Wavenet-B"
        case "fr": return isFemale ? "fr-FR-Wavenet-A"  : "fr-FR-Wavenet-B"
        case "es": return isFemale ? "es-ES-Wavenet-A"  : "es-ES-Wavenet-B"
        case "de": return isFemale ? "de-DE-Wavenet-A"  : "de-DE-Wavenet-B"
        case "ja": return isFemale ? "ja-JP-Wavenet-A"  : "ja-JP-Wavenet-C"
        case "ko": return isFemale ? "ko-KR-Wavenet-A"  : "ko-KR-Wavenet-C"
        case "zh": return isFemale ? "cmn-CN-Wavenet-A" : "cmn-CN-Wavenet-B"
        case "ar": return isFemale ? "ar-XA-Wavenet-A"  : "ar-XA-Wavenet-B"
        case "it": return isFemale ? "it-IT-Wavenet-A"  : "it-IT-Wavenet-C"
        case "pt": return isFemale ? "pt-BR-Wavenet-A"  : "pt-BR-Wavenet-B"
        default:   return nil
        }
    }
}
