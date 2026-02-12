//
//  ChatMessage.swift
//  MVP
//
//  v2.0: Enhanced with mutable text for streaming, persistence support

import Foundation

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    var text: String
    let isFromUser: Bool
    let timestamp: Date
    /// Track whether this message was from voice input
    var wasVoiceInput: Bool
    /// Language code for TTS
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
