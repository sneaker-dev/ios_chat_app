import Foundation

enum APIConfig {
    static var authBaseURL: String {
        ProcessInfo.processInfo.environment["MVP_AUTH_BASE_URL"] ?? "https://appstore-demo.inango.com"
    }

    static var baseURL: String {
        ProcessInfo.processInfo.environment["MVP_API_BASE_URL"] ?? "https://voice-demo.inango.com"
    }

    static var useDemoMode: Bool {
        baseURL.contains("api.example.com")
    }

    static var loginPath: String {
        ProcessInfo.processInfo.environment["MVP_LOGIN_PATH"] ?? "/api/v1/auth/login"
    }
    static var registerPath: String {
        ProcessInfo.processInfo.environment["MVP_REGISTER_PATH"] ?? "/api/v1/auth/register"
    }
    static var dialogPath: String {
        ProcessInfo.processInfo.environment["MVP_DIALOG_PATH"] ?? "/api/v1/intent/generic"
    }
}
