//
//  ChatBubbleView.swift
//  MVP
//
//  v2.0: Production-ready chat bubbles matching Android app.
//  Transparent backgrounds, timestamps, typewriter effect support.

import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    /// For bot messages, when set shows only this many characters (typewriter effect). Nil = show full.
    var displayedCharacterCount: Int? = nil

    private var displayedText: String {
        guard !message.isFromUser, let count = displayedCharacterCount else { return message.text }
        let end = min(count, message.text.count)
        return String(message.text.prefix(end))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.isFromUser { Spacer(minLength: 48) }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                // Message bubble
                HStack(spacing: 0) {
                    if !message.isFromUser {
                        // Bot icon
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.4))
                            .padding(.trailing, 4)
                            .padding(.top, 4)
                    }
                    
                    Text(displayedText)
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            message.isFromUser
                                ? Color.accentColor.opacity(0.85)
                                : Color(.systemGray5).opacity(0.85)
                        )
                        .foregroundColor(message.isFromUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                // Timestamp + voice indicator
                HStack(spacing: 4) {
                    if message.wasVoiceInput {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 4)
            }
            
            if !message.isFromUser { Spacer(minLength: 48) }
        }
        .padding(.horizontal, 12)
        .id(message.id)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 8) {
        ChatBubbleView(message: ChatMessage(text: "Hello!", isFromUser: true, wasVoiceInput: true))
        ChatBubbleView(message: ChatMessage(text: "Hi, how can I help you today?", isFromUser: false))
    }
    .padding()
}
