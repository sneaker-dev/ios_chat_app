import Foundation

enum APIConfig {
    static var authBaseURL: String {
        ProcessInfo.processInfo.environment["MVP_AUTH_BASE_URL"] ?? "https://appstore-demo.inango.com"
    }

    static var baseURL: String {
        ProcessInfo.processInfo.environment["MVP_API_BASE_URL"] ?? "https://voice-demo.inango.com"
    }

    static var supportBaseURL: String {
        ProcessInfo.processInfo.environment["MVP_SUPPORT_BASE_URL"] ?? "https://support-demo.inango.com/support"
    }

    static let appStoreURL = "https://app-store.inango.com"
    static let problemsBaseURL = "http://192.168.68.104:8000"

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
