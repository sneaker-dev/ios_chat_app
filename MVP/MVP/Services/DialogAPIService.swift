import Foundation
import os

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

    func sendMessage(_ text: String, language: String? = nil, baseURL: String? = nil) async throws -> String {
        let normalizedText = sanitizeQueryText(text)
        guard !normalizedText.isEmpty else {
            throw DialogAPIError.serverError("Please say or type a message.")
        }

        guard let token = auth.token() else { throw DialogAPIError.notAuthenticated }

        if APIConfig.useDemoMode {
            return "You said: \"\(normalizedText)\". (Demo mode.)"
        }

        let lang = language ?? DialogAPIService.getDeviceLanguage()
        let locale = TextToSpeechService.formatLocale(lang)
        AppLogger.dialog.debug("sendMessage language=\(lang, privacy: .public) locale=\(locale, privacy: .public) baseURL=\(baseURL ?? APIConfig.baseURL, privacy: .public)")

        let body = InangoGenericRequest(locale: locale, queryText: normalizedText)
        guard let url = resolveEndpointURL(baseURL: baseURL) else { throw DialogAPIError.invalidURL }
        let isSupportRequest = isSupportURL(url)
        let maxRetries = isSupportRequest ? 1 : 4

        return try await performRequest(
            body: body,
            url: url,
            token: token,
            isSupportRequest: isSupportRequest,
            maxRetries: maxRetries,
            normalizedText: normalizedText
        )
    }

    private func performRequest(
        body: InangoGenericRequest,
        url: URL,
        token: String,
        isSupportRequest: Bool,
        maxRetries: Int,
        normalizedText: String
    ) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = isSupportRequest ? 18 : 25

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
                    let bodyPreview = String(data: data, encoding: .utf8) ?? ""
                    AppLogger.dialog.error("sendMessage error status=\(http.statusCode, privacy: .public) url=\(url.absoluteString, privacy: .public) body=\(String(bodyPreview.prefix(300)), privacy: .public)")
                    if http.statusCode == 500 && (bodyPreview.contains("users/user") || bodyPreview.contains("10.0.5.1")) {
                        AppLogger.dialog.error("server-side: backend failed calling internal users service")
                    }
                    let msg = userFacingMessage(from: data, statusCode: http.statusCode)
                    if token.hasPrefix("demo-token-") {
                        return "You said: \"\(normalizedText)\". (Need real login to get answers from voice-demo.inango.com.)"
                    }
                    lastError = .serverError(msg)
                    let isRetryable = http.statusCode >= 500 || http.statusCode == 421
                    if isRetryable && attempt < maxRetries {
                        let delayNs = UInt64(2 + attempt) * 1_000_000_000
                        try await Task.sleep(nanoseconds: delayNs)
                        continue
                    }
                    throw lastError!
                }

                return try parseQueryResponse(data: data)
            } catch {
                AppLogger.dialog.error("sendMessage request failed: \(error.localizedDescription, privacy: .public)")
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
        let transientMessage = "Voice server is temporarily unavailable. Tap Try again or send another message."
        if statusCode >= 500 || statusCode == 421 {
            return transientMessage
        }
        if detail.hasPrefix("<") || detail.lowercased().hasPrefix("<!doctype") {
            return transientMessage
        }
        if detail.contains("Internal Server Error") || detail.contains(" for url: ") || detail.contains("10.") {
            return transientMessage
        }
        return detail.isEmpty ? "Something went wrong. Please try again." : detail
    }

    private func normalizedBaseURL(_ baseURL: String) -> String {
        var normalized = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }

    private func resolveEndpointURL(baseURL: String?) -> URL? {
        guard let override = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines), !override.isEmpty else {
            let defaultBase = normalizedBaseURL(APIConfig.baseURL)
            return URL(string: defaultBase + APIConfig.dialogPath)
        }

        let normalized = normalizedBaseURL(override)
        guard let parsed = URL(string: normalized) else { return nil }
        if parsed.path.hasPrefix("/api/") {
            return parsed
        }
        if let host = parsed.host?.lowercased(), host.contains("support-demo.inango.com") {
            let path = parsed.path.lowercased()
            if path.isEmpty || path == "/" || path == "/support" {
                return URL(string: "https://support-demo.inango.com/api/v1/support/chat")
            }
        }
        return URL(string: normalized + APIConfig.dialogPath)
    }

    private func isSupportURL(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        return host.contains("support-demo.inango.com") || path.contains("/support/chat")
    }

    private func sanitizeQueryText(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        let cleanedScalars = collapsed.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }
        return String(String.UnicodeScalarView(cleanedScalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
