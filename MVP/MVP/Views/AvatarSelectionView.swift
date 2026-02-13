//
//  AvatarSelectionView.swift
//  MVP
//
//  Post-login circle selection + Swipeable avatar change from top bar.

import SwiftUI

// MARK: - Post-Login Avatar Selection (Circle-based)

struct AvatarSelectionView: View {
    var onSelected: (AvatarType) -> Void
    @State private var selectedAvatar: AvatarType? = nil
    @State private var isNavigating = false
    private let avatars = AvatarType.allCases

    var body: some View {
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height

        ZStack {
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

            Color.black.opacity(0.4).ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                Text("Choose Avatar")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Select an avatar to begin")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                Spacer().frame(height: 48)

                HStack(spacing: 0) {
                    Spacer()
                    ForEach(avatars, id: \.self) { avatar in
                        avatarCircle(avatar: avatar, isSelected: selectedAvatar == avatar)
                            .onTapGesture { selectedAvatar = avatar }
                        if avatar != avatars.last {
                            Spacer()
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 48)

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
        .ignoresSafeArea()
    }

    private func avatarCircle(avatar: AvatarType, isSelected: Bool) -> some View {
        let size: CGFloat = 140

        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 4)
                    .frame(width: size + 8, height: size + 8)

                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: size, height: size)

                    // Scale down the avatar so the full person (head to feet) fits inside the circle
                    GIFImageView(avatar.isFemale ? "female_idle" : "male_idle", contentMode: .scaleAspectFit)
                        .frame(width: size * 0.75, height: size * 2.5)
                        .scaleEffect(0.37)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                }
            }

            Circle()
                .fill(isSelected ? Color.appPrimary : Color.white.opacity(0.4))
                .frame(width: 12, height: 12)
        }
    }
}

// MARK: - Swipeable Avatar Change (from top bar)

struct SwipeableAvatarChangeView: View {
    var currentAvatar: AvatarType
    var onSelected: (AvatarType) -> Void
    var onCancel: () -> Void

    @State private var selectedIndex: Int = 0
    @State private var isNavigating = false
    private let avatars = AvatarType.allCases

    var body: some View {
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height

        ZStack {
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

            Color.black.opacity(0.4).ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
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

                Text("Swipe left or right to select")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 4)

                Spacer().frame(height: 16)

                ZStack {
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(avatars.enumerated()), id: \.element) { index, avatar in
                            AvatarView(avatarType: avatar, state: .idle, scale: 1.0)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(maxHeight: .infinity)

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

                Text(avatars[selectedIndex].isFemale ? "Female Assistant" : "Male Assistant")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Spacer().frame(height: 32)

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
            if let idx = avatars.firstIndex(of: currentAvatar) {
                selectedIndex = idx
            }
        }
    }
}
