//
//  AvatarView.swift
//  MVP
//
//  v2.0: Complete rewrite with GIF animation support.
//  Uses ImageIO (built-in, no third-party deps) for animated GIFs.
//  Falls back to static Man.png / Woman.png if GIFs not available.

import SwiftUI
import UIKit
import ImageIO

// MARK: - GIF Loader (ImageIO-based, no third-party dependencies)

final class GIFAnimator {
    /// Load an animated GIF from the app bundle by name (without extension)
    static func createAnimatedImage(from name: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return createAnimatedImage(from: data)
    }

    /// Create an animated UIImage from GIF data
    static func createAnimatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return nil }

        var images: [UIImage] = []
        var totalDuration: Double = 0

        for i in 0..<count {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            images.append(UIImage(cgImage: cgImage))

            if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gifProps = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                let delay = gifProps[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                    ?? gifProps[kCGImagePropertyGIFDelayTime as String] as? Double
                    ?? 0.1
                totalDuration += max(delay, 0.01)
            } else {
                totalDuration += 0.1
            }
        }

        guard !images.isEmpty else { return nil }
        return UIImage.animatedImage(with: images, duration: totalDuration)
    }
}

// MARK: - GIF Image View (UIViewRepresentable)

struct GIFImageView: UIViewRepresentable {
    let gifName: String
    let contentMode: UIView.ContentMode

    init(_ gifName: String, contentMode: UIView.ContentMode = .scaleAspectFit) {
        self.gifName = gifName
        self.contentMode = contentMode
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        loadGIF(into: imageView)
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        // Only reload if the GIF name changed
        if uiView.accessibilityIdentifier != gifName {
            loadGIF(into: uiView)
        }
    }

    private func loadGIF(into imageView: UIImageView) {
        imageView.accessibilityIdentifier = gifName
        if let animatedImage = GIFAnimator.createAnimatedImage(from: gifName) {
            imageView.image = animatedImage
        } else if let staticImage = UIImage(named: gifName) {
            imageView.image = staticImage
        }
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let avatarType: AvatarType
    var state: AvatarAnimState = .idle
    var scale: CGFloat = 1.0
    var showAsCircle: Bool = false

    /// GIF name for current avatar state
    private var gifName: String {
        let prefix = avatarType == .male ? "male" : "female"
        switch state {
        case .idle: return "\(prefix)_idle"
        case .thinking: return "\(prefix)_thinking"
        case .speaking: return "\(prefix)_talking"
        }
    }

    /// Check if GIF file exists in bundle
    private var hasGIF: Bool {
        Bundle.main.url(forResource: gifName, withExtension: "gif") != nil
    }

    var body: some View {
        ZStack {
            if hasGIF {
                // Animated GIF avatar
                GIFImageView(gifName)
                    .scaleEffect(scale)
            } else {
                // Fallback: static image with animation effects
                staticAvatarView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var staticAvatarView: some View {
        Group {
            if let uiImage = avatarUIImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // System fallback icon
                Image(systemName: avatarType == .male ? "person.crop.circle.fill" : "person.crop.circle.badge.checkmark")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(avatarType == .male ? .blue : .pink)
            }
        }
        .clipShape(showAsCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 0)))
        .scaleEffect(scaleForState)
        .opacity(opacityForState)
        .animation(.easeInOut(duration: 0.3), value: state)
    }

    private var avatarUIImage: UIImage? {
        UIImage(named: avatarType == .male ? "Man" : "Woman")
    }

    private var scaleForState: CGFloat {
        switch state {
        case .idle: return 1.0 * scale
        case .thinking: return 1.02 * scale
        case .speaking: return 1.05 * scale
        }
    }

    private var opacityForState: Double {
        switch state {
        case .idle: return 1.0
        case .thinking: return 0.85
        case .speaking: return 1.0
        }
    }
}

// MARK: - Shape Type Erasure (for conditional clip shapes)

struct AnyShape: Shape {
    private let pathClosure: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathClosure = { rect in shape.path(in: rect) }
    }

    func path(in rect: CGRect) -> Path {
        pathClosure(rect)
    }
}

// MARK: - Avatar Background View

struct AvatarBackgroundView: View {
    let avatarType: AvatarType

    var body: some View {
        Group {
            if let uiImage = UIImage(named: avatarType == .male ? "Man" : "Woman") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(avatarType == .male ? UIColor.systemBlue : UIColor.systemPink)
            }
        }
        .clipped()
    }
}

#Preview {
    AvatarView(avatarType: .female, state: .speaking)
        .frame(height: 200)
}
