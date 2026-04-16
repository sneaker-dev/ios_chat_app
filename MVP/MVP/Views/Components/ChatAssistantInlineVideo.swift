import SwiftUI
import AVKit

/// Inline camera / stream playback under an assistant bubble (#45268).
/// Fullscreen uses `fullScreenCover` with the same `AVPlayer` (parity with Android dialog overlay).
struct ChatAssistantInlineVideo: View {
    let url: URL

    @State private var dismissed = false
    @State private var fullscreen = false
    @State private var player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !dismissed {
                ZStack(alignment: .top) {
                    Group {
                        if let p = player, !fullscreen {
                            VideoPlayer(player: p)
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else if !fullscreen {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.35))
                                .frame(maxHeight: 220)
                        }
                    }

                    HStack(alignment: .top) {
                        Button {
                            guard player != nil else { return }
                            fullscreen = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 22, weight: .semibold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.black.opacity(0.55))
                                .padding(8)
                        }
                        .disabled(player == nil)
                        .accessibilityLabel("Fullscreen")

                        Spacer()

                        Button {
                            dismissed = true
                            fullscreen = false
                            player?.pause()
                            player = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.black.opacity(0.55))
                                .padding(8)
                        }
                        .accessibilityLabel("Close video")
                    }
                }
            } else {
                Button("Play video") {
                    dismissed = false
                    let p = AVPlayer(url: url)
                    p.play()
                    player = p
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.95))
            }
        }
        .onAppear {
            guard player == nil, !dismissed else { return }
            let p = AVPlayer(url: url)
            p.play()
            player = p
        }
        .onDisappear {
            player?.pause()
        }
        .onChange(of: dismissed) { newValue in
            if newValue { fullscreen = false }
        }
        .fullScreenCover(isPresented: $fullscreen, onDismiss: { fullscreen = false }) {
            if let p = player {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VideoPlayer(player: p)
                        .ignoresSafeArea()
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                fullscreen = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.black.opacity(0.6))
                                    .padding(16)
                            }
                            .accessibilityLabel("Exit fullscreen")
                        }
                        Spacer()
                    }
                }
            }
        }
    }
}
