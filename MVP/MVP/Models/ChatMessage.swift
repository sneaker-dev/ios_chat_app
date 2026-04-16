import Foundation

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    var text: String
    let isFromUser: Bool
    let timestamp: Date
    var wasVoiceInput: Bool
    var language: String?
    var suppressTTS: Bool
    /// Optional HLS/file URL from intent response (Redmine #45268).
    var videoUrl: String?

    init(
        id: UUID = UUID(),
        text: String,
        isFromUser: Bool,
        timestamp: Date = Date(),
        wasVoiceInput: Bool = false,
        language: String? = nil,
        suppressTTS: Bool = false,
        videoUrl: String? = nil
    ) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.wasVoiceInput = wasVoiceInput
        self.language = language
        self.suppressTTS = suppressTTS
        self.videoUrl = videoUrl
    }
}
