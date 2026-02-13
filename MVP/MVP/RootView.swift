//
//  RootView.swift
//  MVP
//
//  v2.0: Exact Android parity - color palette, splash, navigation, theme

import SwiftUI
import UIKit
import Combine

// MARK: - App Theme (exact Android Color.kt match)

extension Color {
    /// Brand primary: #E55C38 (same in light and dark on Android)
    static let appPrimary = Color(red: 0xE5/255, green: 0x5C/255, blue: 0x38/255)
    static let appPrimaryPressed = Color(red: 0xCF/255, green: 0x4F/255, blue: 0x2F/255)

    /// Dynamic colors matching Android Theme.kt
    static let appBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0x12/255, green: 0x12/255, blue: 0x12/255, alpha: 1)
            : UIColor(red: 0xFA/255, green: 0xFA/255, blue: 0xFA/255, alpha: 1)
    })
    static let appCard = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0x24/255, green: 0x24/255, blue: 0x24/255, alpha: 1)
            : UIColor.white
    })
    static let appTextPrimary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark ? .white : UIColor(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255, alpha: 1)
    })
    static let appTextSecondary = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0xCC/255, green: 0xCC/255, blue: 0xCC/255, alpha: 1)
            : UIColor(red: 0x66/255, green: 0x66/255, blue: 0x66/255, alpha: 1)
    })

    // Chat bubbles (exact Android match)
    static let userBubble = Color.white.opacity(0.85)       // Android: Color.White.copy(alpha = 0.85f)
    static let userBubbleText = Color(red: 0, green: 0, blue: 0) // Android: Color.Black
    static let aiBubble = appPrimary.opacity(0.90)           // Android: primary.copy(alpha = 0.90f)
    static let aiBubbleText = Color.white                    // Android: Color.White

    // Top bar overlay
    static let topBarDark = Color.black.opacity(0.3)         // Android: Color.Black.copy(alpha = 0.3f)
    static let topBarLight = Color.white.opacity(0.3)        // Android: Color.White.copy(alpha = 0.3f)

    // Tap to Speak dark red gradient (Android ButtonColorOption.DarkRed)
    static let speakNormal1 = Color(red: 0xB7/255, green: 0x1C/255, blue: 0x1C/255) // #B71C1C
    static let speakNormal2 = Color(red: 0xD3/255, green: 0x2F/255, blue: 0x2F/255) // #D32F2F
    static let speakActive1 = Color(red: 0xD3/255, green: 0x2F/255, blue: 0x2F/255) // #D32F2F
    static let speakActive2 = Color(red: 0xE5/255, green: 0x73/255, blue: 0x73/255) // #E57373
}

// MARK: - Splash Screen (exact Android SplashScreen.kt match)

struct SplashView: View {
    var onFinished: () -> Void
    @State private var alphaAnim: Double = 0
    @State private var scaleAnim: CGFloat = 0.5
    @State private var pulseScale: CGFloat = 0.8

    var body: some View {
        ZStack {
            // Background image (same as Android: R.drawable.background)
            if UIImage(named: "LoginBackground") != nil {
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            } else {
                LinearGradient(
                    colors: [Color(red: 0x1A/255, green: 0x1A/255, blue: 0x2E/255),
                             Color(red: 0x0F/255, green: 0x0F/255, blue: 0x1E/255)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            // Android: Color.Black.copy(alpha = 0.6f)
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Center content
            VStack(spacing: 24) {
                // Android: app_name, 48.sp, ExtraBold
                Text("Inango Chat")
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundColor(.white)
                    .tracking(3)

                // Android: app_tagline, 18.sp, Medium
                Text("Your AI Voice Assistant")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .tracking(1)

                Spacer().frame(height: 32)

                // Android: Three concentric pulsing circles (60/40/20dp)
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 60, height: 60)
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 40, height: 40)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                }
                .scaleEffect(pulseScale)

                Spacer().frame(height: 16)

                // Android: "Loading...", 14.sp
                Text("Loading...")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            .opacity(alphaAnim)
            .scaleEffect(scaleAnim)

            // Android: version at bottom, 12.sp, padding(bottom = 32.dp)
            VStack {
                Spacer()
                Text("v1.0.0")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 32)
            }
            .opacity(alphaAnim)
        }
        .onAppear {
            // Android: alphaAnim 0→1 (1000ms), scaleAnim 0.5→1 (spring), pulseScale 0.8→1.2 (infinite)
            withAnimation(.easeOut(duration: 1.0)) {
                alphaAnim = 1.0
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0)) {
                scaleAnim = 1.0
            }
            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
            // Android: delay 2500ms then navigate
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { onFinished() }
            }
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @State private var showSplash = true
    @State private var isLoggedIn = AuthService.shared.isLoggedIn
    @State private var hasAvatar: Bool = KeychainService.shared.hasSeenAvatarSelection()
    @State private var selectedAvatar: AvatarType? = KeychainService.shared.getSelectedAvatar()

    var body: some View {
        Group {
            if showSplash {
                SplashView { showSplash = false }
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
                    withAnimation { selectedAvatar = avatar; hasAvatar = true }
                }
                .transition(.opacity)
                .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
                    withAnimation { isLoggedIn = false; hasAvatar = false; selectedAvatar = nil }
                }
            } else if let avatar = selectedAvatar {
                DialogView(avatarType: avatar)
                    .transition(.opacity)
                    .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
                        withAnimation { isLoggedIn = false; hasAvatar = false; selectedAvatar = nil }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .changeAvatar)) { _ in
                        withAnimation { hasAvatar = false; selectedAvatar = nil }
                    }
            }
        }
        .onAppear {
            isLoggedIn = AuthService.shared.isLoggedIn
            hasAvatar = KeychainService.shared.hasSeenAvatarSelection()
            selectedAvatar = KeychainService.shared.getSelectedAvatar()
        }
        // Set tint color globally to match Android primary
        .tint(.appPrimary)
        .accentColor(.appPrimary)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userDidLogin = Notification.Name("userDidLogin")
    static let userDidLogout = Notification.Name("userDidLogout")
    static let changeAvatar = Notification.Name("changeAvatar")
}

// MARK: - Keyboard Avoiding

private struct KeyboardAvoidingModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { n in
                guard let f = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = f.height }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = 0 }
            }
    }
}

extension View {
    func keyboardAvoiding() -> some View { modifier(KeyboardAvoidingModifier()) }
}
