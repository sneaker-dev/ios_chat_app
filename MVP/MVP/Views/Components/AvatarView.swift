//
//  AvatarView.swift
//  MVP
//
//  v2.0: Exact Android AvatarGifDisplay.kt match - GIF loading via ImageIO,
//  state-based GIF selection, ContentScale.Crop equivalent

import SwiftUI
import UIKit
import ImageIO

// MARK: - GIF Loader (ImageIO, no third-party dependencies)

final class GIFAnimator {
    static func createAnimatedImage(from name: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif"),
              let data = try? Data(contentsOf: url) else { return nil }
        return createAnimatedImage(from: data)
    }
    static func createAnimatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            return UIImage(cgImage: cgImage)
        }
        var images: [UIImage] = []
        var totalDuration: Double = 0
        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))
            if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifProps = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                let delay = (gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double)
                    ?? (gifProps[kCGImagePropertyGIFDelayTime as String] as? Double)
                    ?? 0.1
                totalDuration += max(delay, 0.01)
            } else {
                totalDuration += 0.1
            }
        }
        return UIImage.animatedImage(with: images, duration: totalDuration)
    }
}

// MARK: - GIF Image View (UIViewRepresentable)

struct GIFImageView: UIViewRepresentable {
    let gifName: String
    let contentMode: UIView.ContentMode

    init(_ gifName: String, contentMode: UIView.ContentMode = .scaleAspectFill) {
        self.gifName = gifName
        self.contentMode = contentMode // Android uses ContentScale.Crop = scaleAspectFill
    }

    func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = contentMode
        iv.clipsToBounds = true
        iv.backgroundColor = .clear
        loadGIF(into: iv)
        return iv
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if uiView.accessibilityIdentifier != gifName {
            loadGIF(into: uiView)
        }
    }

    private func loadGIF(into imageView: UIImageView) {
        imageView.accessibilityIdentifier = gifName
        if let anim = GIFAnimator.createAnimatedImage(from: gifName) {
            imageView.image = anim
        } else if let static_img = UIImage(named: gifName) {
            imageView.image = static_img
        }
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let avatarType: AvatarType
    var state: AvatarAnimState = .idle
    var scale: CGFloat = 1.0
    var showAsCircle: Bool = false

    // Android GIF naming: female_idle, female_thinking, female_talking, male_idle, male_thinking, male_talking
    private var gifName: String {
        let gender = avatarType.isFemale ? "female" : "male"
        switch state {
        case .idle: return "\(gender)_idle"
        case .thinking: return "\(gender)_thinking"
        case .speaking: return "\(gender)_talking"
        }
    }

    private var hasGIF: Bool {
        Bundle.main.url(forResource: gifName, withExtension: "gif") != nil
    }

    var body: some View {
        ZStack {
            if hasGIF {
                // Animated GIF (Android: Coil with GIF decoder, ContentScale.Crop)
                GIFImageView(gifName, contentMode: .scaleAspectFill)
                    .scaleEffect(scale)
            } else {
                // Fallback: static image with programmatic animation
                staticAvatarView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .if(showAsCircle) { $0.clipShape(Circle()) }
    }

    private var staticAvatarView: some View {
        Group {
            if let img = avatarUIImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(scaleForState)
                    .opacity(opacityForState)
                    .animation(.easeInOut(duration: 0.3), value: state)
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
                    .padding(40)
            }
        }
    }

    private var avatarUIImage: UIImage? {
        UIImage(named: avatarType.isFemale ? "Woman" : "Man")
    }

    private var scaleForState: CGFloat {
        switch state {
        case .idle: return 1.0 * scale
        case .thinking: return 1.02 * scale
        case .speaking: return 1.04 * scale
        }
    }

    private var opacityForState: Double {
        switch state {
        case .idle: return 1.0
        case .thinking: return 0.9
        case .speaking: return 1.0
        }
    }
}

// MARK: - Conditional modifier

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
