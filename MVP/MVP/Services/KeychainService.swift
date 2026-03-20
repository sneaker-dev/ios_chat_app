import Foundation
import Security
import os

final class KeychainService {
    static let shared = KeychainService()

    private let tokenKey = "com.mvp.authToken"
    private let appStoreTokenKey = "com.mvp.appStoreToken"
    private let avatarKey = "com.mvp.selectedAvatar"
    private let hasSeenAvatarSelectionKey = "com.mvp.hasSeenAvatarSelection"
    private let lastEmailKey = "com.mvp.lastEmail"
    private let lastPasswordKey = "com.mvp.lastPassword"
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

    func saveAppStoreToken(_ token: String) {
        save(key: appStoreTokenKey, value: token)
    }

    func getAppStoreToken() -> String? {
        load(key: appStoreTokenKey)
    }

    func removeAppStoreToken() {
        delete(key: appStoreTokenKey)
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

    func resetAvatarSelection() {
        delete(key: hasSeenAvatarSelectionKey)
    }

    func clearAll() {
        removeToken()
        removeAppStoreToken()
        delete(key: lastPasswordKey)
    }

    func saveLastEmail(_ email: String) {
        save(key: lastEmailKey, value: email)
    }

    func getLastEmail() -> String? {
        load(key: lastEmailKey)
    }

    func saveLastPassword(_ password: String) {
        save(key: lastPasswordKey, value: password)
    }

    func getLastPassword() -> String? {
        load(key: lastPasswordKey)
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
        guard let data = value.data(using: .utf8) else {
            AppLogger.keychain.error("save failed: UTF-8 encoding error key=\(key, privacy: .public)")
            return
        }
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            AppLogger.keychain.error("save failed key=\(key, privacy: .public) status=\(status, privacy: .public)")
        }
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
        if status == errSecItemNotFound {
            return nil
        }
        if status != errSecSuccess {
            AppLogger.keychain.warning("load: unexpected status key=\(key, privacy: .public) status=\(status, privacy: .public)")
            return nil
        }
        guard let data = result as? Data else { return nil }
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
