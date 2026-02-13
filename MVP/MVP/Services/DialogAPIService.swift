import Foundation

struct InangoGenericRequest: Encodable {
    let locale: String
    let queryText: String
}

struct InangoQueryResponse: Decodable {
    let queryResponse: String
}

enum DialogAPIError: Error, LocalizedError {
    case notAuthenticated
    case invalidURL
    case noData
    case invalidResponse
    case serverError(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not logged in or session expired. Please log in again."
        case .invalidURL: return "Invalid request URL."
        case .noData: return "No response from server."
        case .invalidResponse: return "Invalid response from server."
        case .serverError(let msg): return msg.isEmpty ? "Server error." : msg
        case .decodingFailed(let msg): return "Could not read response: \(msg)"
        }
    }
}

final class DialogAPIService {
    static let shared = DialogAPIService()
    private let auth = AuthService.shared

    private init() {}

    static func getDeviceLanguage() -> String {
        let rawLanguage = Locale.current.languageCode ?? "en"
        switch rawLanguage {
        case "iw": return "he"
        case "in": return "id"
        case "ji": return "yi"
        default: return rawLanguage
        }
    }

    func sendMessage(_ text: String, language: String? = nil) async throws -> String {
        guard let token = auth.token() else { throw DialogAPIError.notAuthenticated }

        if APIConfig.useDemoMode {
            return "You said: \"\(text)\". (Demo mode.)"
        }

        let lang = language ?? DialogAPIService.getDeviceLanguage()
        let locale = TextToSpeechService.formatLocale(lang)
        
        #if DEBUG
        print("[MVP] Dialog API: language=\(lang), formatted locale=\(locale)")
        #endif
        
        let body = InangoGenericRequest(locale: locale, queryText: text)
        guard let url = URL(string: APIConfig.baseURL + APIConfig.dialogPath) else { throw DialogAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let maxRetries = 4
        var lastError: DialogAPIError?
        for attempt in 0...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw DialogAPIError.invalidResponse }

                if http.statusCode == 401 {
                    AuthService.shared.logout()
                    throw DialogAPIError.notAuthenticated
                }
                if http.statusCode >= 400 {
                    #if DEBUG
                    let bodyPreview = String(data: data, encoding: .utf8) ?? ""
                    print("[MVP] Dialog API error: status=\(http.statusCode) url=\(url.absoluteString) body=\(bodyPreview.prefix(500))")
                    if http.statusCode == 500 && (bodyPreview.contains("users/user") || bodyPreview.contains("10.0.5.1")) {
                        print("[MVP] → Server-side: voice-demo.inango.com's backend failed calling its internal users service.")
                    }
                    #endif
                    let msg = userFacingMessage(from: data, statusCode: http.statusCode)
                    if token.hasPrefix("demo-token-") {
                        return "You said: \"\(text)\". (Need real login to get answers from voice-demo.inango.com.)"
                    }
                    lastError = .serverError(msg)
                    if http.statusCode >= 500 && attempt < maxRetries {
                        let delayNs = UInt64(2 + attempt) * 1_000_000_000
                        try await Task.sleep(nanoseconds: delayNs)
                        continue
                    }
                    throw lastError!
                }

                return try parseQueryResponse(data: data)
            } catch {
                #if DEBUG
                print("[MVP] Dialog API request failed: \(error)")
                #endif
                throw error
            }
        }
        throw lastError ?? .serverError("Voice server is temporarily unavailable. Tap Try again or send another message.")
    }

    private func parseQueryResponse(data: Data) throws -> String {
        if let decoded = try? JSONDecoder().decode(InangoQueryResponse.self, from: data), !decoded.queryResponse.isEmpty {
            return decoded.queryResponse
        }
        struct FlexibleResponse: Decodable {
            let queryResponse: String?
            let response: String?
            let message: String?
            let text: String?
        }
        if let flex = try? JSONDecoder().decode(FlexibleResponse.self, from: data) {
            let text = flex.queryResponse ?? flex.response ?? flex.message ?? flex.text ?? ""
            if !text.isEmpty { return text }
        }
        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            return raw
        }
        throw DialogAPIError.decodingFailed("empty or unexpected format")
    }

    private func userFacingMessage(from data: Data, statusCode: Int) -> String {
        struct ServerErrorBody: Decodable { let detail: String? }
        let raw = String(data: data, encoding: .utf8) ?? ""
        let detail = (try? JSONDecoder().decode(ServerErrorBody.self, from: data))?.detail ?? raw
        if statusCode >= 500 {
            return "Voice server is temporarily unavailable. Tap Try again or send another message."
        }
        if detail.contains("Internal Server Error") || detail.contains(" for url: ") || detail.contains("10.") {
            return "Voice server is temporarily unavailable. Tap Try again or send another message."
        }
        return detail.isEmpty ? "Something went wrong. Please try again." : detail
    }
}
