//
//  AvatarSelectionView.swift
//  MVP
//
//  v2.0: Production-ready avatar selection matching Android app.
//  Background image, swipeable with indicators, no avatar names,
//  double-tap prevention, improved styling.

import SwiftUI

struct AvatarSelectionView: View {
    @State private var selectedAvatar: AvatarType?
    @State private var isNavigating = false
    var onSelected: (AvatarType) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                if UIImage(named: "LoginBackground") != nil {
                    Image("LoginBackground")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.15)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }

                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 28) {
                    Spacer()

                    // Title
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)

                        Text("Choose Your Assistant")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                        Text("Select an avatar to get started")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Avatars with swipe indicators
                    HStack(spacing: 12) {
                        // Left arrow
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .foregroundColor(.white.opacity(0.5))

                        HStack(spacing: 28) {
                            ForEach(AvatarType.allCases, id: \.self) { type in
                                Button {
                                    guard !isNavigating else { return }
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                                        selectedAvatar = type
                                    }
                                } label: {
                                    VStack(spacing: 10) {
                                        ZStack {
                                            // Glow effect for selected
                                            if selectedAvatar == type {
                                                Circle()
                                                    .fill(Color.accentColor.opacity(0.15))
                                                    .frame(width: 160, height: 160)
                                                    .blur(radius: 10)
                                            }

                                            AvatarView(avatarType: type, state: .idle, scale: 1.0, showAsCircle: true)
                                                .frame(width: 140, height: 140)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle()
                                                        .stroke(
                                                            selectedAvatar == type
                                                                ? Color.accentColor
                                                                : Color.white.opacity(0.3),
                                                            lineWidth: selectedAvatar == type ? 4 : 2
                                                        )
                                                )
                                                .shadow(
                                                    color: selectedAvatar == type
                                                        ? Color.accentColor.opacity(0.5)
                                                        : .clear,
                                                    radius: 12
                                                )
                                                .scaleEffect(selectedAvatar == type ? 1.05 : 1.0)
                                        }

                                        // Gender label (subtle)
                                        Text(type == .male ? "Male" : "Female")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Right arrow
                        Image(systemName: "chevron.right")
                            .font(.title2.bold())
                            .foregroundColor(.white.opacity(0.5))
                    }

                    // Continue button
                    if let avatar = selectedAvatar {
                        Button {
                            guard !isNavigating else { return }
                            isNavigating = true
                            KeychainService.shared.saveSelectedAvatar(avatar)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                onSelected(avatar)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Continue")
                                    .font(.headline)
                                Image(systemName: "arrow.right")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: 200)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .cornerRadius(14)
                            .shadow(color: .accentColor.opacity(0.4), radius: 6, y: 3)
                        }
                        .transition(.scale.combined(with: .opacity))
                        .padding(.top, 8)
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: goBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            isNavigating = false
        }
    }

    private func goBack() {
        AuthService.shared.logout()
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }
}

#Preview {
    AvatarSelectionView { _ in }
}
