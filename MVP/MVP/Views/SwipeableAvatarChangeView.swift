//
//  SwipeableAvatarChangeView.swift
//  MVP
//
//  Android SwipeableAvatarSelectionScreen.kt match: Full-screen swipeable avatar
//  with arrows, page dots, and confirm button. Used when changing avatar from top bar.

import SwiftUI

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
            // Background image
            if UIImage(named: "LoginBackground") != nil {
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: screenW, height: screenH)
                    .clipped()
                    .position(x: screenW / 2, y: screenH / 2)
                    .allowsHitTesting(false)
            } else {
                LinearGradient(
                    colors: [Color(red: 0x1A/255, green: 0x1A/255, blue: 0x2E/255),
                             Color(red: 0x0F/255, green: 0x0F/255, blue: 0x1E/255)],
                    startPoint: .top, endPoint: .bottom
                )
            }

            // Overlay
            Color.black.opacity(0.4).allowsHitTesting(false)

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
        .ignoresSafeArea(.container, edges: .all)
        .onAppear {
            // Start on the currently active avatar
            if let idx = avatars.firstIndex(of: currentAvatar) {
                selectedIndex = idx
            }
        }
    }
}
