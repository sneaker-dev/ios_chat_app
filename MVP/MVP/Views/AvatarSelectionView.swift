import SwiftUI

struct AvatarSelectionView: View {
    var onSelected: (AvatarType) -> Void
    @State private var selectedAvatar: AvatarType? = nil
    @State private var isNavigating = false
    private let avatars = AvatarType.allCases

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let screenH = UIScreen.main.bounds.height
            let isLandscape = w > screenH

            ZStack {
                Color.black.ignoresSafeArea()

                if UIImage(named: "LoginBackground") != nil {
                    Image("LoginBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: screenH)
                        .clipped()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                Color.black.opacity(0.4).ignoresSafeArea().allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: isLandscape ? 8 : 20)

                    Text("Choose Avatar")
                        .font(.system(size: isLandscape ? 22 : 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Select an avatar to begin")
                        .font(.system(size: isLandscape ? 14 : 17))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, isLandscape ? 4 : 8)

                    Spacer(minLength: isLandscape ? 8 : 48)

                    HStack(spacing: 0) {
                        Spacer()
                        ForEach(avatars, id: \.self) { avatar in
                            avatarCircle(avatar: avatar, isSelected: selectedAvatar == avatar, isLandscape: isLandscape)
                                .onTapGesture { selectedAvatar = avatar }
                            if avatar != avatars.last {
                                Spacer()
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: isLandscape ? 8 : 48)

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
                            .font(.system(size: isLandscape ? 15 : 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: isLandscape ? 400 : .infinity, minHeight: isLandscape ? 46 : 56)
                            .background(selectedAvatar != nil ? Color.appPrimary : Color.gray.opacity(0.4))
                            .cornerRadius(isLandscape ? 23 : 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedAvatar == nil || isNavigating)
                    .padding(.horizontal, 24)

                    Spacer(minLength: isLandscape ? 8 : 20)
                }
            }
            .frame(width: w, height: screenH)
            .clipped()
        }
        .ignoresSafeArea(.all, edges: .all)
    }

    private func avatarCircle(avatar: AvatarType, isSelected: Bool, isLandscape: Bool) -> some View {
        let screenH = UIScreen.main.bounds.height
        let size: CGFloat = isLandscape ? min(screenH * 0.55, 180) : 160

        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 4)
                    .frame(width: size + 8, height: size + 8)

                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: size, height: size)

                    GIFImageView(avatar.isFemale ? "female_idle" : "male_idle", contentMode: .scaleAspectFill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                }
            }

            Circle()
                .fill(isSelected ? Color.appPrimary : Color.white.opacity(0.4))
                .frame(width: 14, height: 14)
        }
    }
}

struct SwipeableAvatarChangeView: View {
    var currentAvatar: AvatarType
    var onSelected: (AvatarType) -> Void
    var onCancel: () -> Void

    @State private var selectedIndex: Int = 0
    @State private var isNavigating = false
    @State private var isAnimating = false
    private let avatars = AvatarType.allCases

    private var safeIndex: Int {
        min(max(selectedIndex, 0), avatars.count - 1)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let screenH = UIScreen.main.bounds.height
            let isLandscape = w > screenH

            ZStack {
                Color.black.ignoresSafeArea()

                if UIImage(named: "LoginBackground") != nil {
                    Image("LoginBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: w, height: screenH)
                        .clipped()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                Color.black.opacity(0.4).ignoresSafeArea().allowsHitTesting(false)

                VStack(spacing: 0) {
                    HStack {
                        Button(action: {
                            guard !isNavigating else { return }
                            onCancel()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }

                        Text("Choose Your Assistant")
                            .font(.system(size: isLandscape ? 18 : 20, weight: .bold))
                            .foregroundColor(.white)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, isLandscape ? 4 : 8)

                    Text("Swipe left or right to select")
                        .font(.system(size: isLandscape ? 14 : 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, isLandscape ? 2 : 4)

                    Spacer(minLength: isLandscape ? 4 : 16)

                    ZStack {
                        TabView(selection: Binding(
                            get: { safeIndex },
                            set: { newVal in
                                let clamped = min(max(newVal, 0), avatars.count - 1)
                                selectedIndex = clamped
                            }
                        )) {
                            ForEach(Array(avatars.enumerated()), id: \.element) { index, avatar in
                                AvatarView(avatarType: avatar, state: .idle, scale: isLandscape ? 0.9 : 1.0, useAspectFit: isLandscape)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(maxHeight: .infinity)

                        HStack {
                            Button {
                                guard !isAnimating, safeIndex > 0 else { return }
                                isAnimating = true
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedIndex = max(0, safeIndex - 1)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    isAnimating = false
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: isLandscape ? 20 : 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: isLandscape ? 44 : 56, height: isLandscape ? 44 : 56)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .opacity(safeIndex > 0 ? 1 : 0.3)
                            .disabled(safeIndex == 0 || isAnimating)

                            Spacer()

                            Button {
                                guard !isAnimating, safeIndex < avatars.count - 1 else { return }
                                isAnimating = true
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedIndex = min(avatars.count - 1, safeIndex + 1)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    isAnimating = false
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: isLandscape ? 20 : 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: isLandscape ? 44 : 56, height: isLandscape ? 44 : 56)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .opacity(safeIndex < avatars.count - 1 ? 1 : 0.3)
                            .disabled(safeIndex >= avatars.count - 1 || isAnimating)
                        }
                        .padding(.horizontal, 16)
                    }
                    .frame(maxHeight: .infinity)

                    HStack(spacing: 8) {
                        ForEach(0..<avatars.count, id: \.self) { i in
                            Circle()
                                .fill(i == safeIndex ? Color.white : Color.white.opacity(0.5))
                                .frame(
                                    width: i == safeIndex ? 12 : 8,
                                    height: i == safeIndex ? 12 : 8
                                )
                        }
                    }
                    .padding(.top, isLandscape ? 4 : 16)

                    Spacer(minLength: isLandscape ? 4 : 24)

                    Button {
                        guard !isNavigating else { return }
                        isNavigating = true
                        let avatar = avatars[safeIndex]
                        KeychainService.shared.saveSelectedAvatar(avatar)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onSelected(avatar)
                        }
                    } label: {
                        Text("Select Assistant")
                            .font(.system(size: isLandscape ? 14 : 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: isLandscape ? 400 : .infinity, minHeight: isLandscape ? 46 : 56)
                            .background(Color.appPrimary)
                            .cornerRadius(isLandscape ? 23 : 28)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .disabled(isNavigating)

                    Spacer(minLength: isLandscape ? 8 : 32)
                }
            }
            .frame(width: w, height: screenH)
            .clipped()
        }
        .ignoresSafeArea(.all, edges: .all)
        .onAppear {
            if let idx = avatars.firstIndex(of: currentAvatar) {
                selectedIndex = idx
            }
        }
        .onChange(of: selectedIndex) { newValue in
            if newValue < 0 { selectedIndex = 0 }
            else if newValue >= avatars.count { selectedIndex = avatars.count - 1 }
        }
    }
}
