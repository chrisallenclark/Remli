import Foundation
import Security

/// Stores the Claude API key in the iOS Keychain.
///
/// `UserDefaults` would be wrong here: it is a plist in the app container, readable by
/// anything with filesystem access to a backup. An API key is a bearer credential that
/// bills the user's account, so it belongs behind the Secure Enclave-backed store.
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` means the key never leaves this
/// device — it is excluded from iCloud Keychain and from encrypted backups — while still
/// being readable by the background refresh task after a reboot.
enum KeychainStore {

    private static let service = "com.chrisallenclark.remli"
    private static let account = "anthropic.api-key"

    static func save(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return false }

        // Delete-then-add rather than update: it is one code path instead of two, and
        // there is no meaningful cost to it for a single small item.
        delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else { return nil }

        return key
    }

    @discardableResult
    static func delete() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    static var hasKey: Bool { read() != nil }
}
