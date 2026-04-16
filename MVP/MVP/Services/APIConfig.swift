import Foundation

enum APIConfig {
    static var authBaseURL: String {
        ProcessInfo.processInfo.environment["MVP_AUTH_BASE_URL"]
            ?? ServerConfigStore.shared.authBaseURL
    }

    static var baseURL: String {
        ProcessInfo.processInfo.environment["MVP_API_BASE_URL"]
            ?? ServerConfigStore.shared.voiceBaseURL
    }

    /// Host or base URL for Support (same style as `baseURL` / Voice). The streaming client appends
    /// `supportChatAPIPath` unless the user already saved a full `/api/...` URL.
    static var supportBaseURL: String {
        ProcessInfo.processInfo.environment["MVP_SUPPORT_BASE_URL"]
            ?? ServerConfigStore.shared.supportBaseURL
    }

    /// POST path for Support chat, appended when `supportBaseURL` has no `/api/` path.
    static var supportChatAPIPath: String {
        ProcessInfo.processInfo.environment["MVP_SUPPORT_CHAT_PATH"] ?? "/api/v1/support/chat"
    }

    static var appStoreURL: String {
        // Auth and AppStore share the same server; use the user-configured auth URL.
        ProcessInfo.processInfo.environment["MVP_APP_STORE_URL"]
            ?? ServerConfigStore.shared.authBaseURL
    }

    static var problemsBaseURL: String {
        ProcessInfo.processInfo.environment["MVP_PROBLEMS_BASE_URL"]
            ?? ServerConfigStore.shared.problemsBaseURL
    }

    static var appStoreLoginPath: String {
        ProcessInfo.processInfo.environment["MVP_APP_STORE_LOGIN_PATH"] ?? "/api/auth/login"
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
