//
//  ChatBubbleView.swift
//  MVP
//
//  v2.0: Exact Android parity - user=white/black, AI=primary/white,
//  asymmetric corners (4dp on sender side), elevation, padding

import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    var displayedCharacterCount: Int? = nil

    private var displayedText: String {
        guard !message.isFromUser, let count = displayedCharacterCount else { return message.text }
        return String(message.text.prefix(min(count, message.text.count)))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.isFromUser { Spacer(minLength: 48) }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(displayedText)
                    .font(.system(size: 16)) // Android: bodyLarge = 16sp
                    .padding(.horizontal, 16)  // Android: 16.dp
                    .padding(.vertical, 12)    // Android: 12.dp
                    .background(
                        message.isFromUser
                            ? Color.userBubble     // Android: White 85%
                            : Color.aiBubble       // Android: primary 90%
                    )
                    .foregroundColor(
                        message.isFromUser
                            ? Color.userBubbleText  // Android: Black
                            : Color.aiBubbleText    // Android: White
                    )
                    .clipShape(
                        // Android: topStart=16, topEnd=16, user: bottomStart=16/bottomEnd=4, AI: bottomStart=4/bottomEnd=16
                        BubbleShape(isFromUser: message.isFromUser)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1) // Android: elevation 2.dp

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
        .padding(.horizontal, 16) // Android: horizontal 16.dp
        .id(message.id)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}

// Android-matching asymmetric bubble shape
struct BubbleShape: Shape {
    let isFromUser: Bool

    func path(in rect: CGRect) -> Path {
        let tl: CGFloat = 16 // topStart
        let tr: CGFloat = 16 // topEnd
        let bl: CGFloat = isFromUser ? 16 : 4   // bottomStart: user=16, AI=4
        let br: CGFloat = isFromUser ? 4 : 16   // bottomEnd: user=4, AI=16

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 16) {
        ChatBubbleView(message: ChatMessage(text: "Hello!", isFromUser: true, wasVoiceInput: true))
        ChatBubbleView(message: ChatMessage(text: "Hi! How can I help you today?", isFromUser: false))
    }
    .padding()
}
