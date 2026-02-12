//
//  ChatBubbleView.swift
//  MVP
//
//  v2.0: Enhanced with transparent bubbles matching Android app,
//  improved text display, and better spacing

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
        HStack(alignment: .top, spacing: 8) {
            if message.isFromUser { Spacer(minLength: 48) }
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(displayedText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.isFromUser
                            ? Color.accentColor.opacity(0.85)
                            : Color(.systemGray5).opacity(0.85)
                    )
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 4)
            }
            if !message.isFromUser { Spacer(minLength: 48) }
        }
        .padding(.horizontal, 12)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 8) {
        ChatBubbleView(message: ChatMessage(text: "Hello!", isFromUser: true))
        ChatBubbleView(message: ChatMessage(text: "Hi, how can I help?", isFromUser: false))
    }
}
