import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage
    var displayedCharacterCount: Int? = nil

    private var displayedText: String {
        guard !message.isFromUser, let count = displayedCharacterCount else { return message.text }
        return String(message.text.prefix(min(count, message.text.count)))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.isFromUser { Spacer(minLength: 50) }

            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 2) {
                Text(displayedText)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.isFromUser ? Color.userBubble : Color.aiBubble)
                    .foregroundColor(message.isFromUser ? Color.userBubbleText : Color.aiBubbleText)
                    .clipShape(BubbleShape(isFromUser: message.isFromUser))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                HStack(spacing: 3) {
                    if message.wasVoiceInput {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.45))
                }
            }

            if !message.isFromUser { Spacer(minLength: 50) }
        }
        .padding(.horizontal, 12)
        .id(message.id)
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date)
    }
}

struct BubbleShape: Shape {
    let isFromUser: Bool
    func path(in rect: CGRect) -> Path {
        let tl: CGFloat = 16, tr: CGFloat = 16
        let bl: CGFloat = isFromUser ? 16 : 4
        let br: CGFloat = isFromUser ? 4 : 16
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        p.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}
