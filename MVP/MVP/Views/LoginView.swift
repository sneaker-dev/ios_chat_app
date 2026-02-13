//
//  LoginView.swift
//  MVP
//
//  Clean Android-matching login screen. Card layout on background image.

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isRegister = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPassword = false
    @FocusState private var focusedField: Field?
    private enum Field { case email, password }

    var body: some View {
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height

        ZStack {
            // Background (absolute, fills entire screen)
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

            // 50% overlay
            Color.black.opacity(0.5).ignoresSafeArea().allowsHitTesting(false)

            // Content - vertically centered
            VStack(spacing: 0) {
                Spacer()

                // Title
                Text(isRegister ? "Create Account" : "Welcome")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.appPrimary)

                Text(isRegister ? "Create your AI Assistant account" : "Sign in to your AI Assistant")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 6)

                Spacer().frame(height: 28)

                // Card
                VStack(spacing: 16) {
                    // Email
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Email").font(.system(size: 13, weight: .medium))
                            .foregroundColor(focusedField == .email ? .appPrimary : .gray)
                        TextField("Enter your email", text: $email)
                            .focused($focusedField, equals: .email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .submitLabel(.next)
                            .font(.system(size: 15))
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                            .foregroundColor(Color(hex: 0x1A1A1A))
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(focusedField == .email ? Color.appPrimary : Color(hex: 0xE0E0E0), lineWidth: 1.5)
                            )
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Password").font(.system(size: 13, weight: .medium))
                            .foregroundColor(focusedField == .password ? .appPrimary : .gray)
                        HStack(spacing: 0) {
                            Group {
                                if showPassword {
                                    TextField("Enter your password", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.go)
                                } else {
                                    SecureField("Enter your password", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.go)
                                }
                            }
                            .font(.system(size: 15))
                            .frame(height: 46)
                            .foregroundColor(Color(hex: 0x1A1A1A))

                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 40, height: 46)
                            }
                        }
                        .padding(.leading, 14)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(focusedField == .password ? Color.appPrimary : Color(hex: 0xE0E0E0), lineWidth: 1.5)
                        )
                    }

                    // Error
                    if let err = errorMessage {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }

                    // Sign In button
                    Button(action: submit) {
                        ZStack {
                            if isLoading {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(isRegister ? "Create Account" : "Sign In")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            (email.isEmpty || password.isEmpty) ? Color.appPrimary.opacity(0.5) : Color.appPrimary
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                }
                .padding(22)
                .background(Color.white.opacity(0.95))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                .padding(.horizontal, 24)

                // Toggle
                Button(isRegister ? "Already have an account? Sign In" : "Create an account") {
                    withAnimation { isRegister.toggle(); errorMessage = nil }
                }
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 16)

                Spacer()
            }
        }
        .ignoresSafeArea()
        .textFieldStyle(PlainTextFieldStyle())
        .onAppear {
            if email.isEmpty { email = KeychainService.shared.getLastEmail() ?? "" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focusedField = .email }
        }
        .onSubmit {
            if focusedField == .email { focusedField = .password }
            else if focusedField == .password { submit() }
        }
    }

    private func submit() {
        focusedField = nil; errorMessage = nil; isLoading = true
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        Task {
            do {
                if isRegister {
                    try await AuthService.shared.register(email: email, password: password, deviceId: deviceId)
                } else {
                    try await AuthService.shared.login(email: email, password: password, deviceId: deviceId)
                }
                await MainActor.run {
                    KeychainService.shared.saveLastEmail(email)
                    isLoading = false
                    NotificationCenter.default.post(name: .userDidLogin, object: nil)
                }
            } catch let e as AuthError {
                await MainActor.run { isLoading = false; errorMessage = e.localizedDescription }
            } catch {
                await MainActor.run { isLoading = false; errorMessage = error.localizedDescription }
            }
        }
    }
}

// Hex color helper
extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
