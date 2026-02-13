//
//  AvatarSelectionView.swift
//  MVP
//
//  Android AvatarSelectionScreen.kt match: Two circular avatar previews,
//  selection border, indicator dots, "Continue" button. Full-screen background.

import SwiftUI

struct AvatarSelectionView: View {
    var onSelected: (AvatarType) -> Void
    @State private var selectedAvatar: AvatarType? = nil
    @State private var isNavigating = false
    private let avatars = AvatarType.allCases

    var body: some View {
        GeometryReader { geo in
            let screenW = UIScreen.main.bounds.width
            let screenH = UIScreen.main.bounds.height

            ZStack {
                // LAYER 1: Background image (full screen, no gaps)
                if UIImage(named: "LoginBackground") != nil {
                    Image("LoginBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: screenW, height: screenH)
                        .clipped()
                        .allowsHitTesting(false)
                } else {
                    LinearGradient(
                        colors: [Color(red: 0x1A/255, green: 0x1A/255, blue: 0x2E/255),
                                 Color(red: 0x0F/255, green: 0x0F/255, blue: 0x1E/255)],
                        startPoint: .top, endPoint: .bottom
                    )
                }

                // LAYER 2: Overlay (Android: Color.Black.copy(alpha = 0.4f))
                Color.black.opacity(0.4).allowsHitTesting(false)

                // LAYER 3: Content - centered column
                VStack(spacing: 0) {
                    Spacer()

                    // Title (Android: headlineMedium, Bold)
                    Text("Choose Avatar")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    // Subtitle (Android: bodyLarge, onSurfaceVariant)
                    Text("Select an avatar to begin")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    Spacer().frame(height: 48) // Android: 48.dp

                    // Avatar options in a row (Android: Row, SpaceEvenly)
                    HStack(spacing: 0) {
                        Spacer()
                        ForEach(avatars, id: \.self) { avatar in
                            avatarOption(avatar: avatar, isSelected: selectedAvatar == avatar)
                                .onTapGesture { selectedAvatar = avatar }
                            if avatar != avatars.last {
                                Spacer()
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 48) // Android: 48.dp

                    // Continue button (Android: 56.dp height, RoundedCornerShape(28.dp))
                    Button {
                        guard !isNavigating, let avatar = selectedAvatar else { return }
                        isNavigating = true
                        KeychainService.shared.saveSelectedAvatar(avatar)
                        KeychainService.shared.markAvatarAsSelected()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onSelected(avatar)
                        }
                    } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(selectedAvatar != nil ? Color.appPrimary : Color.gray.opacity(0.4))
                            .cornerRadius(28)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedAvatar == nil || isNavigating)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .ignoresSafeArea(.container, edges: .all)
        }
        .ignoresSafeArea(.container, edges: .all)
    }

    // MARK: - Avatar Option (Android: AvatarOption composable)
    // Circular preview with selection border + indicator dot

    @ViewBuilder
    private func avatarOption(avatar: AvatarType, isSelected: Bool) -> some View {
        let circleSize: CGFloat = 140 // Android: 140.dp

        VStack(spacing: 12) {
            // Circular avatar preview
            ZStack {
                // Selection border (Android: 4.dp border, primary color)
                Circle()
                    .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 4)
                    .frame(width: circleSize + 8, height: circleSize + 8)

                // Avatar GIF inside circle
                ZStack {
                    // Background fill (Android: surfaceVariant)
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: circleSize, height: circleSize)

                    // GIF content cropped to circle
                    GIFImageView(avatar.isFemale ? "female_idle" : "male_idle")
                        .frame(width: circleSize, height: circleSize)
                        .clipShape(Circle())
                }
            }

            // Selection indicator dot (Android: 12.dp circle)
            Circle()
                .fill(isSelected ? Color.appPrimary : Color.white.opacity(0.4))
                .frame(width: 12, height: 12)
        }
    }
}
