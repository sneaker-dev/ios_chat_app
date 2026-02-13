//
//  LoginView.swift
//  MVP
//
//  v2.0: Production-ready login screen matching Android app.
//  Background image, branding, show/hide password, text visibility fix.

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

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 50)

                    // App branding
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                            .shadow(color: .blue.opacity(0.4), radius: 8)

                        Text("Inango Chat")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                        Text("Your AI Voice Assistant")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Text(isRegister ? "Create Account" : "Welcome Back")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                    // Login form card
                    VStack(spacing: 16) {
                        // Email
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Email", systemImage: "envelope")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("Enter your email", text: $email)
                                .focused($focusedField, equals: .email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .submitLabel(.next)
                                .frame(height: 44)
                                .foregroundColor(.primary)
                        }

                        Divider()

                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Password", systemImage: "lock")
                                .font(.caption)
                                .foregroundColor(.gray)
                            HStack {
                                if showPassword {
                                    TextField("Enter your password", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .textContentType(isRegister ? .newPassword : .password)
                                        .submitLabel(.go)
                                        .frame(height: 44)
                                        .foregroundColor(.primary)
                                } else {
                                    SecureField("Enter your password", text: $password)
                                        .focused($focusedField, equals: .password)
                                        .textContentType(isRegister ? .newPassword : .password)
                                        .submitLabel(.go)
                                        .frame(height: 44)
                                        .foregroundColor(.primary)
                                }
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.gray)
                                        .frame(width: 30)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 24)
                    .textFieldStyle(PlainTextFieldStyle())

                    // Error message
                    if let err = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(8)
                        .padding(.horizontal, 24)
                    }

                    // Sign In button
                    Button(action: submit) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text(isRegister ? "Create Account" : "Sign In")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(
                        (email.isEmpty || password.isEmpty)
                            ? Color.accentColor.opacity(0.5)
                            : Color.accentColor
                    )
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 340)
                    .shadow(color: .accentColor.opacity(0.3), radius: 5, y: 3)

                    // Toggle register/login
                    Button(isRegister ? "Already have an account? Sign In" : "Create an account") {
                        withAnimation {
                            isRegister.toggle()
                            errorMessage = nil
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1)

                    // Version
                    Text("v1.0.0")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 16)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if email.isEmpty {
                email = KeychainService.shared.getLastEmail() ?? ""
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                focusedField = .email
            }
        }
        .onSubmit {
            if focusedField == .email { focusedField = .password }
            else if focusedField == .password { submit() }
        }
    }

    private func submit() {
        focusedField = nil
        errorMessage = nil
        isLoading = true
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
                    switch e {
                    case .serverError(let msg): errorMessage = msg
                    default: errorMessage = e.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
