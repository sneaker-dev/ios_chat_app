//
//  LoginView.swift
//  MVP
//
//  v2.0: Enhanced with improved UI, text visibility fix,
//  matching Android app's login screen design

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
            Image("LoginBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 40)
                    
                    // App title
                    VStack(spacing: 8) {
                        Text("Inango Chat")
                            .font(.largeTitle.bold())
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

                    VStack(spacing: 16) {
                        // Email field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("Enter your email", text: $email)
                                .focused($focusedField, equals: .email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .submitLabel(.next)
                                .frame(height: 44)
                                .foregroundColor(.primary) // v2.0: Fix text visibility
                        }
                        
                        // Password field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Password")
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
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(12)
                    .frame(maxWidth: 320)
                    .padding(.horizontal, 24)
                    .textFieldStyle(PlainTextFieldStyle())

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(8)
                    }

                    Button(action: submit) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text(isRegister ? "Create Account" : "Sign In")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(email.isEmpty || password.isEmpty || isLoading)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 320)

                    Button(isRegister ? "Already have an account? Sign In" : "Create an account") {
                        isRegister.toggle()
                        errorMessage = nil
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1)
                    
                    // Version
                    Text("v1.0.0")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 20)
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
                    default: errorMessage = e.localizedDescription ?? "Something went wrong"
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
