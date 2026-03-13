import Foundation

/// Bootstrap result from a native App Store login attempt.
struct AppStoreAuthBootstrap {
    let token: String?
    let cookies: [HTTPCookie]
}

/// Handles native HTTP authentication against the App Store backend.
/// Extracted from AppStoreWebViewStore so that auth logic lives in the service layer.
final class AppStoreAuthService {
    static let shared = AppStoreAuthService()
    private init() {}

    /// Attempts to log in using saved credentials and returns a token + cookies on success.
    func login(email: String, password: String) async -> AppStoreAuthBootstrap? {
        let loginPath = APIConfig.appStoreLoginPath
        guard let loginURL = URL(string: APIConfig.appStoreURL + loginPath) else { return nil }

        let body: [String: String] = ["email": email, "password": password]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return nil }
            let cookies = extractCookies(from: http, for: loginURL)
            let token = parseToken(from: data)
            if token != nil || !cookies.isEmpty {
                return AppStoreAuthBootstrap(token: token, cookies: cookies)
            }
        } catch {
            return nil
        }
        return nil
    }

    private func extractCookies(from response: HTTPURLResponse, for url: URL) -> [HTTPCookie] {
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let keyString = key as? String, let valueString = value as? String else { continue }
            headers[keyString] = valueString
        }
        return HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
    }

    private func parseToken(from data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           text.contains("."),
           text.count > 40,
           !text.hasPrefix("{"),
           !text.hasPrefix("[") {
            return text
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return findToken(in: json)
    }

    private func findToken(in value: Any) -> String? {
        if let dict = value as? [String: Any] {
            for key in ["token", "access_token", "access", "jwt"] {
                if let token = dict[key] as? String, !token.isEmpty {
                    return token
                }
            }
            for child in dict.values {
                if let token = findToken(in: child) {
                    return token
                }
            }
        } else if let arr = value as? [Any] {
            for child in arr {
                if let token = findToken(in: child) {
                    return token
                }
            }
        }
        return nil
    }
}
