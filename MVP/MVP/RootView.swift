//
//  RootView.swift
//  MVP
//
//  Simplified flow: Splash → Login → Dialog (no avatar selection, no settings page)
//  Default avatar: uses stored preference or female

import SwiftUI
import UIKit
import Combine

// MARK: - App Theme (Android Color.kt / Theme.kt)

extension Color {
    static let appPrimary = Color(red: 0xE5/255, green: 0x5C/255, blue: 0x38/255)
    static let appPrimaryPressed = Color(red: 0xCF/255, green: 0x4F/255, blue: 0x2F/255)
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
    // Chat bubbles
    static let userBubble = Color.white.opacity(0.85)
    static let userBubbleText = Color.black
    static let aiBubble = appPrimary.opacity(0.90)
    static let aiBubbleText = Color.white
    // Speak button gradient (Android DarkRed)
    static let speakNormal1 = Color(red: 0xB7/255, green: 0x1C/255, blue: 0x1C/255)
    static let speakNormal2 = Color(red: 0xD3/255, green: 0x2F/255, blue: 0x2F/255)
    static let speakActive1 = Color(red: 0xD3/255, green: 0x2F/255, blue: 0x2F/255)
    static let speakActive2 = Color(red: 0xE5/255, green: 0x73/255, blue: 0x73/255)
}

// MARK: - Splash Screen (Android SplashScreen.kt)

struct SplashView: View {
    var onFinished: () -> Void
    @State private var alphaAnim: Double = 0
    @State private var scaleAnim: CGFloat = 0.5
    @State private var pulseScale: CGFloat = 0.8

    var body: some View {
        ZStack {
            if UIImage(named: "LoginBackground") != nil {
                Image("LoginBackground").resizable().scaledToFill().ignoresSafeArea().allowsHitTesting(false)
            } else {
                LinearGradient(colors: [Color(hex: 0x1A1A2E), Color(hex: 0x0F0F1E)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            }
            Color.black.opacity(0.6).ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 24) {
                Text("Inango Chat").font(.system(size: 48, weight: .heavy)).foregroundColor(.white).tracking(3)
                Text("Your AI Voice Assistant").font(.system(size: 18, weight: .medium)).foregroundColor(.white.opacity(0.9)).tracking(1)
                Spacer().frame(height: 32)
                ZStack {
                    Circle().fill(Color.white.opacity(0.3)).frame(width: 60, height: 60)
                    Circle().fill(Color.white.opacity(0.6)).frame(width: 40, height: 40)
                    Circle().fill(Color.white).frame(width: 20, height: 20)
                }
                .scaleEffect(pulseScale)
                Spacer().frame(height: 16)
                Text("Loading...").font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
            }
            .opacity(alphaAnim).scaleEffect(scaleAnim)

            VStack { Spacer(); Text("v1.0.0").font(.system(size: 12)).foregroundColor(.white.opacity(0.5)).padding(.bottom, 32) }.opacity(alphaAnim)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { alphaAnim = 1.0 }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { scaleAnim = 1.0 }
            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { pulseScale = 1.2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { onFinished() } }
        }
    }
}

// MARK: - Root View (Simplified: Splash → Login → Dialog)

struct RootView: View {
    @State private var showSplash = true
    @State private var isLoggedIn = AuthService.shared.isLoggedIn

    /// Use stored avatar or default to female
    private var activeAvatar: AvatarType {
        KeychainService.shared.getSelectedAvatar() ?? .female
    }

    var body: some View {
        Group {
            if showSplash {
                SplashView { showSplash = false }
                    .transition(.opacity)
            } else if !isLoggedIn {
                LoginView()
                    .transition(.opacity)
                    .onReceive(NotificationCenter.default.publisher(for: .userDidLogin)) { _ in
                        withAnimation { isLoggedIn = true }
                    }
            } else {
                DialogView(avatarType: activeAvatar)
                    .transition(.opacity)
                    .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
                        withAnimation { isLoggedIn = false }
                    }
            }
        }
        .onAppear { isLoggedIn = AuthService.shared.isLoggedIn }
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
