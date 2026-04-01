import Foundation
import Combine

/// Persists user-configurable server endpoint overrides in UserDefaults.
/// Only accessible to users with an @inango-systems.com email address.
final class ServerConfigStore: ObservableObject {
    static let shared = ServerConfigStore()

    // MARK: - Defaults

    static let defaultAuthBaseURL     = "https://appstore-demo.inango.com"
    static let defaultVoiceBaseURL    = "https://voice-demo.inango.com"
    static let defaultSupportBaseURL  = "https://support-demo.inango.com"
    static let defaultProblemsBaseURL = "https://dash-emulator.inango.com"

    private static let inangoDomain = "inango-systems.com"

    // MARK: - UserDefaults keys

    private enum Keys {
        static let authBaseURL     = "server_config_auth_base_url"
        static let voiceBaseURL    = "server_config_voice_base_url"
        static let supportBaseURL  = "server_config_support_base_url"
        static let problemsBaseURL = "server_config_problems_base_url"
    }

    // MARK: - Published properties (changes persist immediately)

    @Published var authBaseURL: String {
        didSet { UserDefaults.standard.set(authBaseURL, forKey: Keys.authBaseURL) }
    }

    @Published var voiceBaseURL: String {
        didSet { UserDefaults.standard.set(voiceBaseURL, forKey: Keys.voiceBaseURL) }
    }

    @Published var supportBaseURL: String {
        didSet { UserDefaults.standard.set(supportBaseURL, forKey: Keys.supportBaseURL) }
    }

    @Published var problemsBaseURL: String {
        didSet { UserDefaults.standard.set(problemsBaseURL, forKey: Keys.problemsBaseURL) }
    }

    // MARK: - Init

    private init() {
        let ud = UserDefaults.standard
        authBaseURL     = ud.string(forKey: Keys.authBaseURL)     ?? Self.defaultAuthBaseURL
        voiceBaseURL    = ud.string(forKey: Keys.voiceBaseURL)    ?? Self.defaultVoiceBaseURL
        supportBaseURL  = ud.string(forKey: Keys.supportBaseURL)  ?? Self.defaultSupportBaseURL
        problemsBaseURL = ud.string(forKey: Keys.problemsBaseURL) ?? Self.defaultProblemsBaseURL
    }

    // MARK: - Domain check

    /// Returns `true` when the signed-in user's email belongs to the Inango domain.
    var isInangoDomain: Bool {
        guard let email = KeychainService.shared.getLastEmail() else { return false }
        return email.lowercased().hasSuffix("@\(Self.inangoDomain)")
    }

    // MARK: - Actions

    func resetToDefaults() {
        authBaseURL     = Self.defaultAuthBaseURL
        voiceBaseURL    = Self.defaultVoiceBaseURL
        supportBaseURL  = Self.defaultSupportBaseURL
        problemsBaseURL = Self.defaultProblemsBaseURL
    }

    // MARK: - Validation

    /// Returns `true` when the string is a syntactically valid http/https URL with a host.
    static func isValidURL(_ string: String) -> Bool {
        guard let url = URL(string: string),
              let scheme = url.scheme,
              (scheme == "http" || scheme == "https"),
              let host = url.host, !host.isEmpty else { return false }
        return true
    }
}
