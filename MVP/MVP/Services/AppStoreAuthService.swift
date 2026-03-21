import Foundation

struct AppStoreAuthBootstrap {
    let token: String?
    let cookies: [HTTPCookie]
}

final class AppStoreAuthService {
    static let shared = AppStoreAuthService()
    private init() {}

    func login(email: String, password: String) async -> AppStoreAuthBootstrap? {
        let loginPath = APIConfig.appStoreLoginPath
        guard let loginURL = URL(string: APIConfig.appStoreURL + loginPath) else { return nil }

        let body: [String: String] = ["email": email, "password": password]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: loginURL)
        request.httpMethod = "PUT"
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
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              text.contains("."),
              text.count > 40,
              !text.hasPrefix("{"),
              !text.hasPrefix("[") else { return nil }
        return text
    }
}
