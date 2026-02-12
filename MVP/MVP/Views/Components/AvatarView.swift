//
//  AvatarView.swift
//  MVP
//
//  v2.0: Updated to use AvatarAnimState from AvatarType.swift
//  Uses Man.png / Woman.png from Assets (male → Man, female → Woman).

import SwiftUI

struct AvatarView: View {
    let avatarType: AvatarType
    var state: AvatarAnimState = .idle
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            avatarImageView
                .scaleEffect(scaleEffectForState)
                .opacity(opacityForState)
                .animation(.easeInOut(duration: 0.3), value: state)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var avatarImageView: some View {
        Group {
            if let uiImage = avatarUIImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: avatarType == .male ? "person.crop.circle.fill" : "person.crop.circle.badge.checkmark")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(avatarType == .male ? .blue : .pink)
            }
        }
        .clipShape(Circle())
    }

    private var avatarUIImage: UIImage? {
        let name = avatarType == .male ? "Man" : "Woman"
        return UIImage(named: name)
    }

    /// Scale effect based on avatar state
    private var scaleEffectForState: CGFloat {
        switch state {
        case .idle: return 1.0 * scale
        case .thinking: return 1.02 * scale  // Subtle pulse for thinking
        case .speaking: return 1.05 * scale   // Slightly larger when speaking
        }
    }
    
    /// Opacity effect (subtle pulse for thinking)
    private var opacityForState: Double {
        switch state {
        case .idle: return 1.0
        case .thinking: return 0.9
        case .speaking: return 1.0
        }
    }
}

/// Avatar image used as background for chat. Male → Man.png, Female → Woman.png.
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
