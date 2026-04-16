import Foundation
import os

struct InangoGenericRequest: Encodable {
    let locale: String
    let queryText: String
}

struct InangoQueryResponse: Decodable {
    let queryResponse: String
    let videoUrl: String?
    enum CodingKeys: String, CodingKey {
        case queryResponse
        case videoUrl
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        queryResponse = try c.decode(String.self, forKey: .queryResponse)
        videoUrl = try c.decodeIfPresent(String.self, forKey: .videoUrl).flatMap { $0.isEmpty ? nil : $0 }
    }
}

/// Parsed assistant reply from generic or support intent (Redmine #45268).
struct DialogQueryResult: Sendable {
    let queryResponse: String
    let videoUrl: String?
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

    /// Dedicated session for Support streaming: no URL cache on disk, `reloadIgnoringLocalCacheData` so bytes are
    /// consumed as delivered instead of going through behaviors tied to the shared session cache.
    private static let supportStreamingSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 600
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - TEMP camera IoT client stub (parity with Android #45268; remove when backend serves this intent)

    private static let stubCameraVideoURL =
        "https://storage.googleapis.com/exoplayer-test-media-0/BigBuckBunny_320x180.mp4"
    private static let stubCameraQueryResponse =
        "Here is a sample stream (temporary in-app stub until chat supports this intent)."

    private static let cameraIntentStubRegexes: [NSRegularExpression] = {
        let patterns = [
            "^stub\\s+camera\\s+stream\\s*$",
            "^__stub_camera_stream__\\s*$",
            "^show\\s+(me\\s+)?the\\s+camera\\b",
            "^display\\s+the\\s+camera\\b",
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    private func matchesCameraIntentStub(_ trimmed: String) -> Bool {
        let ns = trimmed as NSString
        let full = NSRange(location: 0, length: ns.length)
        return Self.cameraIntentStubRegexes.contains { $0.firstMatch(in: trimmed, options: [], range: full) != nil }
    }

    private func stubCameraIntentResult(for normalizedText: String) -> DialogQueryResult? {
        let t = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard matchesCameraIntentStub(t) else { return nil }
        AppLogger.dialog.warning("TEMP camera IoT stub: bypassing API for query=\(t, privacy: .public) (remove with backend #45268)")
        return DialogQueryResult(queryResponse: Self.stubCameraQueryResponse, videoUrl: Self.stubCameraVideoURL)
    }

    static func getDeviceLanguage() -> String {
        let rawLanguage = Locale.current.languageCode ?? "en"
        switch rawLanguage {
        case "iw": return "he"
        case "in": return "id"
        case "ji": return "yi"
        default: return rawLanguage
        }
    }

    func sendMessage(_ text: String, language: String? = nil, baseURL: String? = nil) async throws -> DialogQueryResult {
        let normalizedText = sanitizeQueryText(text)
        guard !normalizedText.isEmpty else {
            throw DialogAPIError.serverError("Please say or type a message.")
        }

        guard let token = auth.token() else { throw DialogAPIError.notAuthenticated }

        if let stub = stubCameraIntentResult(for: normalizedText) {
            return stub
        }

        if APIConfig.useDemoMode {
            return DialogQueryResult(
                queryResponse: "You said: \"\(normalizedText)\". (Demo mode.)",
                videoUrl: nil
            )
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
    ) async throws -> DialogQueryResult {
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
                        return DialogQueryResult(
                            queryResponse: "You said: \"\(normalizedText)\". (Need real login to get answers from voice-demo.inango.com.)",
                            videoUrl: nil
                        )
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

                return try parseQueryResult(data: data)
            } catch let urlErr as URLError {
                let retryableCodes: [URLError.Code] = [
                    .networkConnectionLost, .notConnectedToInternet,
                    .timedOut, .cannotConnectToHost, .cannotFindHost,
                    .dnsLookupFailed, .resourceUnavailable
                ]
                AppLogger.dialog.error("sendMessage URLError code=\(urlErr.code.rawValue, privacy: .public) attempt=\(attempt, privacy: .public) msg=\(urlErr.localizedDescription, privacy: .public)")
                if retryableCodes.contains(urlErr.code) && attempt < maxRetries {
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

    private func parseQueryResult(data: Data) throws -> DialogQueryResult {
        if let decoded = try? JSONDecoder().decode(InangoQueryResponse.self, from: data), !decoded.queryResponse.isEmpty {
            return DialogQueryResult(queryResponse: decoded.queryResponse, videoUrl: decoded.videoUrl)
        }
        struct FlexibleResponse: Decodable {
            let queryResponse: String?
            let response: String?
            let message: String?
            let text: String?
            let videoUrl: String?
        }
        if let flex = try? JSONDecoder().decode(FlexibleResponse.self, from: data) {
            let text = flex.queryResponse ?? flex.response ?? flex.message ?? flex.text ?? ""
            if !text.isEmpty {
                let v = flex.videoUrl.flatMap { $0.isEmpty ? nil : $0 }
                return DialogQueryResult(queryResponse: text, videoUrl: v)
            }
        }
        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            return DialogQueryResult(queryResponse: raw, videoUrl: nil)
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
                return resolveSupportChatURL("https://support-demo.inango.com")
            }
        }
        return URL(string: normalized + APIConfig.dialogPath)
    }

    /// Resolves the Support streaming POST URL. Settings may store only a host (like Voice URL);
    /// in that case append `supportChatAPIPath`. If the string already contains `/api/`, use it as-is.
    private func resolveSupportChatURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let parsed = URL(string: trimmed) else { return nil }
        let path = parsed.path.lowercased()
        if path.contains("/api/") {
            return parsed
        }
        let base = normalizedBaseURL(trimmed)
        return URL(string: base + APIConfig.supportChatAPIPath)
    }

    func sendSupportMessageStreaming(
        _ text: String,
        language: String? = nil,
        onKeepAlive: @Sendable @escaping (String) async -> Void
    ) async throws -> DialogQueryResult {
        let normalizedText = sanitizeQueryText(text)
        guard !normalizedText.isEmpty else {
            throw DialogAPIError.serverError("Please say or type a message.")
        }
        guard let token = auth.token() else { throw DialogAPIError.notAuthenticated }

        if let stub = stubCameraIntentResult(for: normalizedText) {
            return stub
        }

        if APIConfig.useDemoMode {
            return DialogQueryResult(
                queryResponse: "You said: \"\(normalizedText)\". (Demo mode.)",
                videoUrl: nil
            )
        }

        let lang   = language ?? DialogAPIService.getDeviceLanguage()
        let locale = TextToSpeechService.formatLocale(lang)
        let body   = InangoGenericRequest(locale: locale, queryText: normalizedText)

        guard let url = resolveSupportChatURL(APIConfig.supportBaseURL) else { throw DialogAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)",  forHTTPHeaderField: "Authorization")
        // identity: prefer uncompressed body so gzip does not batch small server writes before decode.
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 30

        AppLogger.dialog.debug("sendSupportMessageStreaming url=\(url.absoluteString, privacy: .public)")

        let asyncBytes: URLSession.AsyncBytes
        let urlResponse: URLResponse
        do {
            (asyncBytes, urlResponse) = try await Self.supportStreamingSession.bytes(for: request)
        } catch let urlErr as URLError {
            AppLogger.dialog.error("sendSupportMessageStreaming connect failed code=\(urlErr.code.rawValue, privacy: .public)")
            throw DialogAPIError.serverError("Connection to server lost. Please try again.")
        }
        // All other errors (including CancellationError) propagate as-is.

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
        var finalVideoUrl: String?
        var keepAliveStreamBuffer = ""

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
                        finalVideoUrl = obj.videoUrl
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
                    } else if let finalPayload = extractFinalQueryResult(from: trimmed) {
                        finalText = finalPayload.queryResponse
                        finalVideoUrl = finalPayload.videoUrl
                        break
                    } else {
                        AppLogger.dialog.notice("Unrecognized streaming line: \(String(trimmed.prefix(120)), privacy: .public)")
                    }
                }
            } else {
                lineBuffer.append(ch)
                // Emit keep-alive as soon as `</keep-alive>` is present without waiting for `\n`
                // (chunked streams may omit line breaks between events; BugID 45011).
                if keepAliveStreamBuffer.isEmpty,
                   lineBuffer.lowercased().contains("</keep-alive>") {
                    await drainCompleteKeepAliveSegments(lineBuffer: &lineBuffer, onKeepAlive: onKeepAlive)
                }
            }
        }
        // URLErrors from mid-stream (e.g. server restart) propagate as-is to the caller's catch.

        if finalText == nil, !keepAliveStreamBuffer.isEmpty {
            if let kaText = extractKeepAliveInner(from: keepAliveStreamBuffer) {
                await onKeepAlive(kaText)
            }
            keepAliveStreamBuffer = ""
        }

        if finalText == nil, !lineBuffer.isEmpty {
            await drainCompleteKeepAliveSegments(lineBuffer: &lineBuffer, onKeepAlive: onKeepAlive)
            let trimmed = lineBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if let kaText = extractKeepAliveInner(from: trimmed) {
                await onKeepAlive(kaText)
            } else if let finalPayload = extractFinalQueryResult(from: trimmed) {
                finalText = finalPayload.queryResponse
                finalVideoUrl = finalPayload.videoUrl
            }
        }

        guard let result = finalText, !result.isEmpty else {
            throw DialogAPIError.noData
        }
        return DialogQueryResult(queryResponse: result, videoUrl: finalVideoUrl)
    }

    /// Emit complete keep-alive segments as soon as the closing tag appears (no newline required).
    private func drainCompleteKeepAliveSegments(
        lineBuffer: inout String,
        onKeepAlive: @Sendable @escaping (String) async -> Void
    ) async {
        while true {
            guard let endRange = lineBuffer.range(of: "</keep-alive>", options: .caseInsensitive),
                  let startRange = lineBuffer.range(of: "<keep-alive>", options: .caseInsensitive),
                  startRange.lowerBound < endRange.lowerBound else { break }
            let segment = String(lineBuffer[..<endRange.upperBound])
            guard let kaText = extractKeepAliveInner(from: segment) else { break }
            AppLogger.dialog.debug("keep-alive (incremental) received: \(kaText.prefix(80), privacy: .public)")
            await onKeepAlive(kaText)
            lineBuffer.removeSubrange(..<endRange.upperBound)
            trimStaleJsonAfterKeepAliveDrain(&lineBuffer)
        }
    }

    private func trimStaleJsonAfterKeepAliveDrain(_ buffer: inout String) {
        while buffer.first?.isWhitespace == true { buffer.removeFirst() }
        if buffer.first == "," {
            buffer.removeFirst()
            while buffer.first?.isWhitespace == true { buffer.removeFirst() }
        }
        if buffer.first == "\"" {
            buffer.removeFirst()
            while buffer.first?.isWhitespace == true { buffer.removeFirst() }
        }
        if buffer.first == "}" {
            buffer.removeFirst()
            while buffer.first?.isWhitespace == true { buffer.removeFirst() }
        }
    }

    /// Inner text between `<keep-alive>` and `</keep-alive>` (case-insensitive). Works for JSON `queryResponse`, raw XML-ish lines, or buffered multi-line payloads.
    private func extractKeepAliveInner(from text: String) -> String? {
        guard let startRange = text.range(of: "<keep-alive>", options: .caseInsensitive),
              let endRange = text.range(of: "</keep-alive>", options: .caseInsensitive),
              startRange.upperBound <= endRange.lowerBound else { return nil }
        return String(text[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractFinalQueryResult(from line: String) -> DialogQueryResult? {
        if let data = line.data(using: .utf8),
           let obj = try? JSONDecoder().decode(InangoQueryResponse.self, from: data) {
            let r = obj.queryResponse
            guard !r.lowercased().contains("<keep-alive>"), !r.isEmpty else { return nil }
            return DialogQueryResult(queryResponse: r, videoUrl: obj.videoUrl)
        }
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !t.lowercased().contains("<keep-alive>") else { return nil }
        return DialogQueryResult(queryResponse: t, videoUrl: nil)
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
