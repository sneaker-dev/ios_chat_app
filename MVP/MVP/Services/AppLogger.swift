import os

/// Central log handles for every subsystem in the app.
/// Usage:  AppLogger.auth.info("login attempt")
/// All logs are visible in Console.app filtered by subsystem "com.inango.mvp".
/// Privacy: never log raw passwords or tokens — use .private(mask: .hash) for IDs.
enum AppLogger {
    private static let subsystem = "com.inango.mvp"

    /// Authentication — login, register, logout, token lifecycle
    static let auth      = Logger(subsystem: subsystem, category: "auth")

    /// Keychain — save, load, delete operations
    static let keychain  = Logger(subsystem: subsystem, category: "keychain")

    /// Dialog API — outgoing messages, responses, retries, errors
    static let dialog    = Logger(subsystem: subsystem, category: "dialog")

    /// Speech-to-Text — recording start/stop, permissions, recognition errors
    static let stt       = Logger(subsystem: subsystem, category: "stt")

    /// Text-to-Speech — speak calls, audio session, voice selection
    static let tts       = Logger(subsystem: subsystem, category: "tts")

    /// App Store WebView — load, navigation, landscape form injection
    static let appStore  = Logger(subsystem: subsystem, category: "appstore")

    /// Navigation — screen transitions, app launch path
    static let navigation = Logger(subsystem: subsystem, category: "navigation")
}
