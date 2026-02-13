//
//  AvatarView.swift
//  MVP
//
//  GIF avatar display using ImageIO. Falls back to static images.

import SwiftUI
import UIKit
import ImageIO

// MARK: - GIF Loader

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
            guard let img = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            return UIImage(cgImage: img)
        }
        var images: [UIImage] = []; var duration: Double = 0
        for i in 0..<count {
            guard let img = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            images.append(UIImage(cgImage: img))
            if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
               let gif = props[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                let d = (gif[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double) ?? (gif[kCGImagePropertyGIFDelayTime as String] as? Double) ?? 0.1
                duration += max(d, 0.01)
            } else { duration += 0.1 }
        }
        return UIImage.animatedImage(with: images, duration: duration)
    }
}

// MARK: - GIF Image View

struct GIFImageView: UIViewRepresentable {
    let gifName: String
    init(_ gifName: String) { self.gifName = gifName }

    func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .clear
        loadGIF(into: iv)
        return iv
    }
    func updateUIView(_ uiView: UIImageView, context: Context) {
        if uiView.accessibilityIdentifier != gifName { loadGIF(into: uiView) }
    }
    private func loadGIF(into iv: UIImageView) {
        iv.accessibilityIdentifier = gifName
        if let anim = GIFAnimator.createAnimatedImage(from: gifName) { iv.image = anim }
        else if let img = UIImage(named: gifName) { iv.image = img }
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let avatarType: AvatarType
    var state: AvatarAnimState = .idle
    var scale: CGFloat = 1.0
    var showAsCircle: Bool = false

    private var gifName: String {
        let g = avatarType.isFemale ? "female" : "male"
        switch state {
        case .idle: return "\(g)_idle"
        case .thinking: return "\(g)_thinking"
        case .speaking: return "\(g)_talking"
        }
    }

    private var hasGIF: Bool {
        Bundle.main.url(forResource: gifName, withExtension: "gif") != nil
    }

    var body: some View {
        ZStack {
            if hasGIF {
                GIFImageView(gifName).scaleEffect(scale)
            } else {
                staticView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var staticView: some View {
        Group {
            if let img = UIImage(named: avatarType.isFemale ? "Woman" : "Man") {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(state == .speaking ? 1.04 * scale : state == .thinking ? 1.02 * scale : scale)
                    .animation(.easeInOut(duration: 0.3), value: state)
            } else {
                Image(systemName: "person.fill")
                    .resizable().scaledToFit()
                    .foregroundColor(.gray).padding(40)
            }
        }
    }
}
