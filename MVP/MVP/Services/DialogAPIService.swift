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
            } catch let urlErr as URLError {
                let isRetryableConnection = [
                    URLError.networkConnectionLost,
                    URLError.notConnectedToInternet,
                    URLError.cannotConnectToHost,
                    URLError.cannotFindHost,
                    URLError.timedOut
                ].contains(urlErr.code)
                AppLogger.dialog.error("sendMessage URLError code=\(urlErr.code.rawValue, privacy: .public) attempt=\(attempt, privacy: .public)")
                if isRetryableConnection && attempt < maxRetries {
                    let delayNs = UInt64(1 + attempt) * 1_000_000_000
                    try? await Task.sleep(nanoseconds: delayNs)
                    lastError = .serverError("Connection interrupted. Retrying…")
                    continue
                }
                throw DialogAPIError.serverError(
                    urlErr.code == .notConnectedToInternet
                        ? "No network connection. Please check your connection and try again."
                        : "Connection to server lost. Please try again."
                )
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

    func sendSupportMessageStreaming(
        _ text: String,
        language: String? = nil,
        onKeepAlive: @Sendable @escaping (String) async -> Void
    ) async throws -> String {
        let normalizedText = sanitizeQueryText(text)
        guard !normalizedText.isEmpty else {
            throw DialogAPIError.serverError("Please say or type a message.")
        }
        guard let token = auth.token() else { throw DialogAPIError.notAuthenticated }

        if APIConfig.useDemoMode {
            return "You said: \"\(normalizedText)\". (Demo mode.)"
        }

        let lang   = language ?? DialogAPIService.getDeviceLanguage()
        let locale = TextToSpeechService.formatLocale(lang)
        let body   = InangoGenericRequest(locale: locale, queryText: normalizedText)

        guard let url = URL(string: APIConfig.supportBaseURL) else { throw DialogAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)",  forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30

        AppLogger.dialog.debug("sendSupportMessageStreaming url=\(url.absoluteString, privacy: .public)")

        let asyncBytes: URLSession.AsyncBytes
        let urlResponse: URLResponse
        do {
            (asyncBytes, urlResponse) = try await URLSession.shared.bytes(for: request)
        } catch let urlErr as URLError {
            AppLogger.dialog.error("sendSupportMessageStreaming connect failed code=\(urlErr.code.rawValue, privacy: .public)")
            throw DialogAPIError.serverError("Connection to server lost. Please try again.")
        } catch {
            throw DialogAPIError.serverError("Failed to connect. Please try again.")
        }

        guard let http = urlResponse as? HTTPURLResponse else { throw DialogAPIError.invalidResponse }
        if http.statusCode == 401 {
            AuthService.shared.logout()
            throw DialogAPIError.notAuthenticated
        }
        guard (200...299).contains(http.statusCode) else {
            AppLogger.dialog.error("sendSupportMessageStreaming status=\(http.statusCode, privacy: .public)")
            let msg = http.statusCode == 404 || http.statusCode == 403
                ? "Service unavailable for this account. Please contact your administrator."
                : "Server returned \(http.statusCode)."
            throw DialogAPIError.serverError(msg)
        }

        var lineBuffer = ""
        var finalText: String?
        var keepAliveStreamBuffer = ""

        do {
        for try await byte in asyncBytes {
            let ch = Character(UnicodeScalar(byte))
            if ch == "\n" {
                let line = lineBuffer
                lineBuffer = ""

                if !keepAliveStreamBuffer.isEmpty {
                    keepAliveStreamBuffer += "\n" + line
                    if keepAliveStreamBuffer.lowercased().contains("</keep-alive>") {
                        let assembled = keepAliveStreamBuffer
                        keepAliveStreamBuffer = ""
                        if let kaText = extractKeepAliveInner(from: assembled) {
                            AppLogger.dialog.debug("keep-alive (multi-line) received: \(kaText.prefix(80), privacy: .public)")
                            await onKeepAlive(kaText)
                        }
                    }
                    continue
                }

                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                var handled = false
                if let data = trimmed.data(using: .utf8),
                   let obj = try? JSONDecoder().decode(InangoQueryResponse.self, from: data) {
                    let r = obj.queryResponse
                    if let kaText = extractKeepAliveInner(from: r) {
                        AppLogger.dialog.debug("keep-alive received: \(kaText.prefix(80), privacy: .public)")
                        await onKeepAlive(kaText)
                        handled = true
                    } else if !r.isEmpty, !r.lowercased().contains("<keep-alive>") {
                        finalText = r
                        break
                    } else if r.lowercased().contains("<keep-alive>"), !r.lowercased().contains("</keep-alive>") {
                        keepAliveStreamBuffer = trimmed
                        handled = true
                    } else {
                        handled = true
                    }
                }

                if !handled {
                    let lower = trimmed.lowercased()
                    if lower.contains("<keep-alive>"), lower.contains("</keep-alive>"),
                       let kaText = extractKeepAliveInner(from: trimmed) {
                        AppLogger.dialog.debug("keep-alive (raw) received: \(kaText.prefix(80), privacy: .public)")
                        await onKeepAlive(kaText)
                    } else if lower.contains("<keep-alive>") {
                        keepAliveStreamBuffer = trimmed
                    } else if let final_ = extractFinalResponseText(from: trimmed) {
                        finalText = final_
                        break
                    } else {
                        AppLogger.dialog.notice("Unrecognized streaming line: \(String(trimmed.prefix(120)), privacy: .public)")
                    }
                }
            } else {
                lineBuffer.append(ch)
            }
        }
        } catch let urlErr as URLError {
            AppLogger.dialog.error("sendSupportMessageStreaming stream interrupted code=\(urlErr.code.rawValue, privacy: .public)")
            if let partial = finalText, !partial.isEmpty { return partial }
            throw DialogAPIError.serverError("Connection lost during response. Please try again.")
        } catch {
            throw error
        }

        if finalText == nil, !keepAliveStreamBuffer.isEmpty {
            if let kaText = extractKeepAliveInner(from: keepAliveStreamBuffer) {
                await onKeepAlive(kaText)
            }
            keepAliveStreamBuffer = ""
        }

        if finalText == nil, !lineBuffer.isEmpty {
            let trimmed = lineBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if let kaText = extractKeepAliveInner(from: trimmed) {
                await onKeepAlive(kaText)
            } else {
                finalText = extractFinalResponseText(from: trimmed)
            }
        }

        guard let result = finalText, !result.isEmpty else {
            throw DialogAPIError.noData
        }
        return result
    }

    /// Inner text between `<keep-alive>` and `</keep-alive>` (case-insensitive). Works for JSON `queryResponse`, raw XML-ish lines, or buffered multi-line payloads.
    private func extractKeepAliveInner(from text: String) -> String? {
        guard let startRange = text.range(of: "<keep-alive>", options: .caseInsensitive),
              let endRange = text.range(of: "</keep-alive>", options: .caseInsensitive),
              startRange.upperBound <= endRange.lowerBound else { return nil }
        return String(text[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractFinalResponseText(from line: String) -> String? {
        if let data = line.data(using: .utf8),
           let obj = try? JSONDecoder().decode(InangoQueryResponse.self, from: data) {
            let r = obj.queryResponse
            guard !r.lowercased().contains("<keep-alive>"), !r.isEmpty else { return nil }
            return r
        }
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !t.lowercased().contains("<keep-alive>") else { return nil }
        return t
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
