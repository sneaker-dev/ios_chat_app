import Foundation
import os

final class SessionManager {
    static let shared = SessionManager()

    private(set) var isAuthenticated: Bool
    private var sessionExpiredNotified = false
    private let stateLock = NSLock()

    private init() {
        isAuthenticated = KeychainService.shared.getToken() != nil
    }

    func markAuthenticated() {
        stateLock.lock()
        isAuthenticated = true
        sessionExpiredNotified = false
        stateLock.unlock()
    }

    func markLoggedOut(resetUnauthorizedFlag: Bool = true) {
        stateLock.lock()
        isAuthenticated = false
        if resetUnauthorizedFlag {
            sessionExpiredNotified = false
        }
        stateLock.unlock()
    }

    /// Emits a single global "session expired" event for clustered 401 responses.
    func handleUnauthorized() {
        var shouldNotify = false
        stateLock.lock()
        if !sessionExpiredNotified {
            sessionExpiredNotified = true
            isAuthenticated = false
            shouldNotify = true
        }
        stateLock.unlock()

        guard shouldNotify else { return }
        AuthService.shared.logout(resetUnauthorizedFlag: false)
        NotificationCenter.default.post(name: .sessionExpired, object: nil)
    }
}

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RegisterRequest: Encodable {
    let email: String
    let password: String
    let device_id: String?
}

struct AuthResponse: Decodable {
    let token: String?
    let access_token: String?
    let access: String?
    let user: UserInfo?

    var resolvedToken: String? { token ?? access_token ?? access }
}

struct UserInfo: Decodable {
    let id: String?
    let email: String?
}

enum AuthError: Error, LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case serverError(String)
    case endpointNotFound

    var errorDescription: String? {
        switch self {
        case .serverError(let msg): return msg
        case .endpointNotFound: return "Server endpoint not found. Signed in locally."
        case .invalidURL: return "Invalid URL"
        case .noData: return "No data"
        case .invalidResponse: return "Invalid response"
        }
    }
}

final class AuthService {
    static let shared = AuthService()
    private let keychain = KeychainService.shared

    private init() {}

    var isLoggedIn: Bool { keychain.getToken() != nil }

    func register(email: String, password: String, deviceId: String) async throws {
        AppLogger.auth.info("register attempt email=\(email, privacy: .private(mask: .hash))")
        if APIConfig.useDemoMode {
            AppLogger.auth.info("register: demo mode — skipping server call")
            keychain.saveToken("demo-token-\(email)")
            return
        }
        let body = RegisterRequest(email: email, password: password, device_id: deviceId)
        let token = try await postAuth(path: APIConfig.registerPath, body: body)
        keychain.saveToken(token)
        AppLogger.auth.info("register success")
    }

    func login(email: String, password: String, deviceId: String) async throws {
        AppLogger.auth.info("login attempt email=\(email, privacy: .private(mask: .hash)) deviceId=\(deviceId, privacy: .private(mask: .hash))")
        if APIConfig.useDemoMode {
            AppLogger.auth.info("login: demo mode — skipping server call")
            keychain.saveToken("demo-token-\(email)")
            SessionManager.shared.markAuthenticated()
            return
        }
        let body = LoginRequest(email: email, password: password)
        let token = try await postAuth(path: APIConfig.loginPath, body: body)
        keychain.saveToken(token)
        SessionManager.shared.markAuthenticated()
        AppLogger.auth.info("login success")
    }

    func logout(resetUnauthorizedFlag: Bool = true) {
        AppLogger.auth.info("logout — clearing keychain")
        keychain.clearAll()
        SessionManager.shared.markLoggedOut(resetUnauthorizedFlag: resetUnauthorizedFlag)
    }

    func token() -> String? { keychain.getToken() }

    private func postAuth<T: Encodable>(path: String, body: T) async throws -> String {
        guard let url = URL(string: APIConfig.authBaseURL + path) else { throw AuthError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let deviceId = KeychainService.shared.getOrCreateDeviceId()
        let appVersion = "1.3.26"
        request.setValue("InangoChatApp/\(appVersion) (device_id=\(deviceId); platform=iOS)", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)
        AppLogger.auth.info("postAuth url=\(url.absoluteString, privacy: .public)")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            AppLogger.auth.error("postAuth: invalid response type")
            throw AuthError.invalidResponse
        }
        AppLogger.auth.info("postAuth status=\(http.statusCode, privacy: .public)")
        if http.statusCode == 401 {
            AppLogger.auth.warning("postAuth 401 — removing token")
            SessionManager.shared.handleUnauthorized()
            throw AuthError.serverError("Invalid credentials")
        }
        if http.statusCode >= 400 {
            let message = userFacingServerMessage(data: data, statusCode: http.statusCode)
            AppLogger.auth.error("postAuth error status=\(http.statusCode, privacy: .public) message=\(message, privacy: .public)")
            throw AuthError.serverError(message)
        }
        return try parseToken(from: data)
    }

    private func parseToken(from data: Data) throws -> String {
        if let decoded = try? JSONDecoder().decode(AuthResponse.self, from: data), let t = decoded.resolvedToken, !t.isEmpty {
            return t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.contains("."), raw.count > 50, !raw.hasPrefix("{") {
            return raw
        }
        throw AuthError.invalidResponse
    }

    private func parseErrorDetail(data: Data) -> String? {
        struct ErrorDetail: Decodable { let detail: String? }
        guard let decoded = try? JSONDecoder().decode(ErrorDetail.self, from: data) else { return nil }
        return decoded.detail
    }

    private func userFacingServerMessage(data: Data, statusCode: Int) -> String {
        let detail = parseErrorDetail(data: data) ?? String(data: data, encoding: .utf8) ?? "Server error"
        if statusCode >= 500 { return "Server is temporarily unavailable. Please try again in a moment." }
        if detail.contains("Internal Server Error") || detail.contains(" for url: ") || detail.contains("10.") {
            return "Server is temporarily unavailable. Please try again later."
        }
        return detail
    }
}
