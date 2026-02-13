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
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height

        ZStack {
            // LAYER 1: Background (absolute, fills entire screen)
            Color.black.ignoresSafeArea()

            if UIImage(named: "LoginBackground") != nil {
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: screenW, height: screenH)
                    .clipped()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // LAYER 2: Overlay (Android: Color.Black.copy(alpha = 0.4f))
            Color.black.opacity(0.4).ignoresSafeArea().allowsHitTesting(false)

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
        }
        .ignoresSafeArea()
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

                // Avatar GIF inside circle (scaleAspectFit to show full person)
                ZStack {
                    // Background fill (Android: surfaceVariant)
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: circleSize, height: circleSize)

                    // GIF content fitted to circle - full person visible
                    GIFImageView(avatar.isFemale ? "female_idle" : "male_idle", contentMode: .scaleAspectFit)
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

// MARK: - Swipeable Avatar Change View
// Android SwipeableAvatarSelectionScreen.kt match: Full-screen swipeable avatar
// with arrows, page dots, and confirm button. Used when changing avatar from top bar.

struct SwipeableAvatarChangeView: View {
    var currentAvatar: AvatarType
    var onSelected: (AvatarType) -> Void
    var onCancel: () -> Void

    @State private var selectedIndex: Int = 0
    @State private var isNavigating = false
    private let avatars = AvatarType.allCases

    private let screenW = UIScreen.main.bounds.width
    private let screenH = UIScreen.main.bounds.height

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            if UIImage(named: "LoginBackground") != nil {
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: screenW, height: screenH)
                    .clipped()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Overlay
            Color.black.opacity(0.4).ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                // Top bar with back button and title
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }

                    Text("Choose Your Assistant")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                // Instruction text
                Text("Swipe left or right to select")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 4)

                Spacer().frame(height: 16)

                // Avatar display with swipe + arrows
                ZStack {
                    // Swipeable avatar (full-screen within area)
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(avatars.enumerated()), id: \.element) { index, avatar in
                            AvatarView(avatarType: avatar, state: .idle, scale: 1.0)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(maxHeight: .infinity)

                    // Left/right arrows
                    HStack {
                        if selectedIndex > 0 {
                            Button { withAnimation { selectedIndex -= 1 } } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                        Spacer()
                        if selectedIndex < avatars.count - 1 {
                            Button { withAnimation { selectedIndex += 1 } } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxHeight: .infinity)

                Spacer().frame(height: 16)

                // Page indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<avatars.count, id: \.self) { i in
                        Circle()
                            .fill(i == selectedIndex ? Color.white : Color.white.opacity(0.5))
                            .frame(
                                width: i == selectedIndex ? 12 : 8,
                                height: i == selectedIndex ? 12 : 8
                            )
                    }
                }

                Spacer().frame(height: 24)

                // Gender label
                Text(avatars[selectedIndex].isFemale ? "Female Assistant" : "Male Assistant")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Spacer().frame(height: 32)

                // Confirm button
                Button {
                    guard !isNavigating else { return }
                    isNavigating = true
                    let avatar = avatars[selectedIndex]
                    KeychainService.shared.saveSelectedAvatar(avatar)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onSelected(avatar)
                    }
                } label: {
                    Text("Select Assistant")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.appPrimary)
                        .cornerRadius(28)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .disabled(isNavigating)

                Spacer().frame(height: 32)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Start on the currently active avatar
            if let idx = avatars.firstIndex(of: currentAvatar) {
                selectedIndex = idx
            }
        }
    }
}
