//
//  LoginView.swift
//  MVP
//
//  v2.0: Exact Android LoginScreen.kt match - card layout,
//  colors, dimensions, typography

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
        ZStack {
            // Android: R.drawable.background, ContentScale.Crop
            if UIImage(named: "LoginBackground") != nil {
                Image("LoginBackground").resizable().scaledToFill().ignoresSafeArea().allowsHitTesting(false)
            } else {
                Color(red: 0x1A/255, green: 0x1A/255, blue: 0x2E/255).ignoresSafeArea()
            }

            // Android: Color.Black.copy(alpha = 0.5f)
            Color.black.opacity(0.5).ignoresSafeArea().allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 80)

                    // Android: headlineLarge, Bold, primary color
                    Text(isRegister ? "Create Account" : "Welcome")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.appPrimary)

                    Spacer().frame(height: 8) // Android: 8.dp

                    // Android: bodyLarge, onSurfaceVariant
                    Text(isRegister ? "Create your AI Assistant account" : "Sign in to your AI Assistant")
                        .font(.system(size: 16))
                        .foregroundColor(.appTextSecondary)

                    Spacer().frame(height: 32) // Android: 32.dp

                    // Login card (Android: Card, RoundedCornerShape(24.dp), elevation 16.dp)
                    VStack(spacing: 0) {
                        // Email field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email")
                                .font(.system(size: 14))
                                .foregroundColor(focusedField == .email ? .appPrimary : Color(hex: 0x666666))
                            TextField("Enter your email", text: $email)
                                .focused($focusedField, equals: .email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .submitLabel(.next)
                                .frame(height: 44)
                                .foregroundColor(Color(hex: 0x1A1A1A))
                                .padding(.horizontal, 12)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12) // Android: 12.dp
                                        .stroke(focusedField == .email ? Color.appPrimary : Color(hex: 0xE0E0E0), lineWidth: 1)
                                )
                        }

                        Spacer().frame(height: 16) // Android: 16.dp

                        // Password field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Password")
                                .font(.system(size: 14))
                                .foregroundColor(focusedField == .password ? .appPrimary : Color(hex: 0x666666))
                            HStack {
                                if showPassword {
                                    TextField("Enter your password", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.go)
                                        .frame(height: 44)
                                        .foregroundColor(Color(hex: 0x1A1A1A))
                                } else {
                                    SecureField("Enter your password", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.go)
                                        .frame(height: 44)
                                        .foregroundColor(Color(hex: 0x1A1A1A))
                                }
                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(Color(hex: 0x666666)) // Android: tint
                                }
                            }
                            .padding(.horizontal, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focusedField == .password ? Color.appPrimary : Color(hex: 0xE0E0E0), lineWidth: 1)
                            )
                        }

                        // Error
                        if let err = errorMessage {
                            Spacer().frame(height: 8)
                            Text(err)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

                        Spacer().frame(height: 24) // Android: 24.dp

                        // Sign In button (Android: Button, 56.dp height)
                        Button(action: submit) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity, minHeight: 56)
                            } else {
                                Text(isRegister ? "Create Account" : "Sign In")
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(maxWidth: .infinity, minHeight: 56)
                            }
                        }
                        .background(Color.appPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(email.isEmpty || password.isEmpty || isLoading)
                        .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1.0)

                        Spacer().frame(height: 16)
                    }
                    .padding(32) // Android: 32.dp inner padding
                    .background(Color.white.opacity(0.95)) // Android: White 95%
                    .cornerRadius(24) // Android: 24.dp
                    .shadow(color: .black.opacity(0.15), radius: 16, y: 8) // Android: elevation 16.dp
                    .padding(.horizontal, 24) // Android: 24.dp screen padding

                    Spacer().frame(height: 16)

                    // Toggle register/login
                    Button(isRegister ? "Already have an account? Sign In" : "Create an account") {
                        withAnimation { isRegister.toggle(); errorMessage = nil }
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)

                    Spacer().frame(height: 40)
                }
            }
        }
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
                await MainActor.run {
                    isLoading = false
                    switch e { case .serverError(let m): errorMessage = m; default: errorMessage = e.localizedDescription }
                }
            } catch {
                await MainActor.run { isLoading = false; errorMessage = error.localizedDescription }
            }
        }
    }
}

// Helper for hex colors
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
