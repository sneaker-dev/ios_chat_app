//
//  AvatarSelectionView.swift
//  MVP
//
//  v2.0: Enhanced with swipeable selection, background image, no avatar names

import SwiftUI

struct AvatarSelectionView: View {
    @State private var selectedAvatar: AvatarType?
    @State private var isNavigating = false  // Prevent double-tap
    var onSelected: (AvatarType) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                // Background image
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                VStack(spacing: 24) {
                    Text("Choose Your Assistant")
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                    // v2.0: Swipeable avatars with arrow indicators
                    HStack(spacing: 16) {
                        // Left arrow
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack(spacing: 32) {
                            ForEach(AvatarType.allCases, id: \.self) { type in
                                Button {
                                    guard !isNavigating else { return }
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedAvatar = type
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        AvatarView(avatarType: type, state: .idle, scale: 1.2)
                                            .frame(width: 140, height: 140)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedAvatar == type ? Color.accentColor : Color.white.opacity(0.3), lineWidth: selectedAvatar == type ? 4 : 2)
                                            )
                                            .shadow(color: selectedAvatar == type ? Color.accentColor.opacity(0.5) : .clear, radius: 10)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Right arrow
                        Image(systemName: "chevron.right")
                            .font(.title2.bold())
                            .foregroundColor(.white.opacity(0.6))
                    }

                    if let avatar = selectedAvatar {
                        Button("Continue") {
                            guard !isNavigating else { return }
                            isNavigating = true
                            KeychainService.shared.saveSelectedAvatar(avatar)
                            // Small delay to prevent double-tap navigation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                onSelected(avatar)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 14)
                        .padding(.horizontal, 32)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .font(.headline)
                        .padding(.top, 8)
                    }
                }
                .padding(32)
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
    }

    private func goBack() {
        AuthService.shared.logout()
        NotificationCenter.default.post(name: .userDidLogout, object: nil)
    }
}

#Preview {
    AvatarSelectionView { _ in }
}
