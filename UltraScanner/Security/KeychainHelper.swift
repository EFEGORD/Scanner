import Foundation
import Security

/// Thin wrapper around the Keychain. Every item stored here uses
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: it never syncs to iCloud Keychain and
/// never leaves this device — if the phone is lost without a prior manual export, the data
/// is gone for good. That trade-off was a deliberate product decision (see SETUP.md).
enum KeychainHelper {
    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
        case dataConversionFailed
    }

    static func save(_ data: Data, service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    }

    static func load(service: String, account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = result as? Data else { throw KeychainError.dataConversionFailed }
        return data
    }
}
