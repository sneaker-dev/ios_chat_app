//
//  RootView.swift
//  MVP
//
//  Flow: not logged in → Login; logged in but no avatar → AvatarSelection; else → Dialog.
//

import SwiftUI
import UIKit
import Combine

struct RootView: View {
    @State private var isLoggedIn = AuthService.shared.isLoggedIn
    @State private var hasAvatar: Bool = KeychainService.shared.hasSeenAvatarSelection()
    @State private var selectedAvatar: AvatarType? = KeychainService.shared.getSelectedAvatar()

    var body: some View {
        Group {
            if !isLoggedIn {
                LoginView()
                    .onReceive(NotificationCenter.default.publisher(for: .userDidLogin)) { _ in
                        isLoggedIn = true
                        hasAvatar = KeychainService.shared.hasSeenAvatarSelection()
                    }
            } else if !hasAvatar || selectedAvatar == nil {
                AvatarSelectionView { avatar in
                    selectedAvatar = avatar
                    hasAvatar = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
                    isLoggedIn = false
                    hasAvatar = false
                    selectedAvatar = nil
                }
            } else if let avatar = selectedAvatar {
                DialogView(avatarType: avatar)
                    .onReceive(NotificationCenter.default.publisher(for: .userDidLogout)) { _ in
                        isLoggedIn = false
                        hasAvatar = false
                        selectedAvatar = nil
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

extension Notification.Name {
    static let userDidLogin = Notification.Name("userDidLogin")
    static let userDidLogout = Notification.Name("userDidLogout")
}

// MARK: - Keyboard avoiding (so keyboard appears at bottom, content shifts up)
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
