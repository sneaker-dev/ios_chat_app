import Foundation

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    var text: String
    let isFromUser: Bool
    let timestamp: Date
    var wasVoiceInput: Bool
    var language: String?

    init(id: UUID = UUID(), text: String, isFromUser: Bool, timestamp: Date = Date(), wasVoiceInput: Bool = false, language: String? = nil) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.wasVoiceInput = wasVoiceInput
        self.language = language
    }
}
