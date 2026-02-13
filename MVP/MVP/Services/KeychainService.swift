import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()

    private let tokenKey = "com.mvp.authToken"
    private let avatarKey = "com.mvp.selectedAvatar"
    private let hasSeenAvatarSelectionKey = "com.mvp.hasSeenAvatarSelection"
    private let lastEmailKey = "com.mvp.lastEmail"
    private let deviceIdKey = "com.mvp.deviceId"

    private init() {}

    func saveToken(_ token: String) {
        save(key: tokenKey, value: token)
    }

    func getToken() -> String? {
        load(key: tokenKey)
    }

    func removeToken() {
        delete(key: tokenKey)
    }

    func saveSelectedAvatar(_ avatar: AvatarType) {
        save(key: avatarKey, value: avatar.rawValue)
        save(key: hasSeenAvatarSelectionKey, value: "1")
    }

    func getSelectedAvatar() -> AvatarType? {
        guard let raw = load(key: avatarKey), let avatar = AvatarType(rawValue: raw) else { return nil }
        return avatar
    }

    func hasSeenAvatarSelection() -> Bool {
        load(key: hasSeenAvatarSelectionKey) != nil
    }

    func markAvatarAsSelected() {
        save(key: hasSeenAvatarSelectionKey, value: "1")
    }

    func clearAll() {
        removeToken()
    }

    func saveLastEmail(_ email: String) {
        save(key: lastEmailKey, value: email)
    }

    func getLastEmail() -> String? {
        load(key: lastEmailKey)
    }

    func getOrCreateDeviceId() -> String {
        if let existing = load(key: deviceIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        save(key: deviceIdKey, value: newId)
        return newId
    }

    private func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
