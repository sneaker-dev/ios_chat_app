//
//  RootView.swift
//  MVP
//
//  v2.0: Complete rewrite with SplashView, change avatar flow,
//  and notification-based navigation matching Android app

import SwiftUI
import UIKit
import Combine

// MARK: - Splash Screen

struct SplashView: View {
    var onFinished: () -> Void
    @State private var logoScale: CGFloat = 0.7
    @State private var logoOpacity: Double = 0.0

    var body: some View {
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

            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 16) {
                Spacer()

                // Logo
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
                    .shadow(color: .blue.opacity(0.5), radius: 10)

                Text("Inango Chat")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)

                Text("Your AI Voice Assistant")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.3)
                    .padding(.bottom, 16)

                Text("v1.0.0")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 40)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onFinished()
                }
            }
        }
    }
}

// MARK: - Root View (Navigation Controller)

struct RootView: View {
    @State private var showSplash = true
    @State private var isLoggedIn = AuthService.shared.isLoggedIn
    @State private var hasAvatar: Bool = KeychainService.shared.hasSeenAvatarSelection()
    @State private var selectedAvatar: AvatarType? = KeychainService.shared.getSelectedAvatar()

    var body: some View {
        Group {
            if showSplash {
                SplashView {
                    showSplash = false
                }
                .transition(.opacity)
            } else if !isLoggedIn {
                LoginView()
                    .transition(.opacity)
                    .onReceive(NotificationCenter.default.publisher(for: .userDidLogin)) { _ in
                        withAnimation {
                            isLoggedIn = true
                            hasAvatar = KeychainService.shared.hasSeenAvatarSelection()
                            selectedAvatar = KeychainService.shared.getSelectedAvatar()
                        }
                    }
            } else if !hasAvatar || selectedAvatar == nil {
                AvatarSelectionView { avatar in
                    withAnimation {
                        selectedAvatar = avatar
                        hasAvatar = true
                    }
                }
                .transition(.opacity)
                .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
                    withAnimation {
                        isLoggedIn = false
                        hasAvatar = false
                        selectedAvatar = nil
                    }
                }
            } else if let avatar = selectedAvatar {
                DialogView(avatarType: avatar)
                    .transition(.opacity)
                    .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
                        withAnimation {
                            isLoggedIn = false
                            hasAvatar = false
                            selectedAvatar = nil
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .changeAvatar)) { _ in
                        withAnimation {
                            hasAvatar = false
                            selectedAvatar = nil
                        }
                    }
            }
        }
        .onAppear {
            isLoggedIn = AuthService.shared.isLoggedIn
            hasAvatar = KeychainService.shared.hasSeenAvatarSelection()
            selectedAvatar = KeychainService.shared.getSelectedAvatar()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userDidLogin = Notification.Name("userDidLogin")
    static let userDidLogout = Notification.Name("userDidLogout")
    static let changeAvatar = Notification.Name("changeAvatar")
    static let clearChatHistory = Notification.Name("clearChatHistory")
}

// MARK: - Keyboard Avoiding

private struct KeyboardAvoidingModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = frame.height
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
    }
}

extension View {
    func keyboardAvoiding() -> some View {
        modifier(KeyboardAvoidingModifier())
    }
}
