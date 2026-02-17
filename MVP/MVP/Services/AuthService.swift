import Foundation

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
        if APIConfig.useDemoMode {
            keychain.saveToken("demo-token-\(email)")
            return
        }
        let body = RegisterRequest(email: email, password: password, device_id: deviceId)
        let token = try await postAuth(path: APIConfig.registerPath, body: body)
        keychain.saveToken(token)
    }

    func login(email: String, password: String, deviceId: String) async throws {
        if APIConfig.useDemoMode {
            keychain.saveToken("demo-token-\(email)")
            return
        }
        let body = LoginRequest(email: email, password: password)
        let token = try await postAuth(path: APIConfig.loginPath, body: body)
        keychain.saveToken(token)
    }

    func logout() {
        keychain.clearAll()
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
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        if http.statusCode == 401 {
            keychain.removeToken()
            throw AuthError.serverError("Invalid credentials")
        }
        if http.statusCode >= 400 {
            let message = userFacingServerMessage(data: data, statusCode: http.statusCode)
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
