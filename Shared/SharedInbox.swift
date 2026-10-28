import Foundation
import Security

/// Where the share extension ("Compartir" › UltraScanner in Fotos, WhatsApp, Mail, Archivos…)
/// leaves the photos and PDFs it receives, for the app to import: a Keychain access group that only
/// the app and the extension can read. Everything waiting is encrypted by the system and never
/// leaves the phone, and the app deletes it right after reading it (ImportInbox).
///
/// Each share is one "batch": one item per file (account "<batch>/001.jpg", in the order shared)
/// and, once every file is in, a marker item (account "<batch>"). The app only takes batches with a
/// marker, so it never sees half a share.
enum SharedInbox {
    /// Also in both targets' keychain-access-groups (project.yml). The app lists its own group
    /// first, so its own secrets (the database key) never land in this one.
    static let accessGroup = "C6XD8H2J47.mx.com.claudita.ultrascanner.inbox"
    /// The extension opens the app with this URL once the batch is ready.
    static let openURL = URL(string: "ultrascanner://import")!
    private static let service = "mx.com.claudita.ultrascanner.inbox"

    struct Batch: Equatable {
        let name: String
        /// File names in the order they were shared.
        let files: [String]
    }

    /// A new batch's name: sorts by time, unique.
    static func batchName() -> String {
        "\(Int(Date.now.timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(8))"
    }

    // MARK: - Writing (extension)

    static func add(_ data: Data, batch: String, file: String) -> Bool {
        add(data, account: "\(batch)/\(file)")
    }

    static func markReady(_ batch: String) -> Bool {
        add(Data(), account: batch)
    }

    private static func add(_ data: Data, account: String) -> Bool {
        var item = query(account: account)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Reading (app)

    /// Every item waiting (account and when it was written), without the data.
    static func entries() -> [(account: String, created: Date)] {
        var search = query(account: nil)
        search[kSecReturnAttributes as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitAll
        var result: AnyObject?
        guard SecItemCopyMatching(search as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let account = item[kSecAttrAccount as String] as? String else { return nil }
            return (account, item[kSecAttrCreationDate as String] as? Date ?? .distantPast)
        }
    }

    /// The complete batches among `accounts`, oldest first.
    static func readyBatches(in accounts: [String]) -> [Batch] {
        let markers = Set(accounts.filter { !$0.contains("/") })
        var files: [String: [String]] = [:]
        for account in accounts {
            let parts = account.split(separator: "/", maxSplits: 1).map(String.init)
            if parts.count == 2 { files[parts[0], default: []].append(parts[1]) }
        }
        return markers.sorted().map { Batch(name: $0, files: (files[$0] ?? []).sorted()) }
    }

    static func data(batch: String, file: String) -> Data? {
        var search = query(account: "\(batch)/\(file)")
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(search as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func remove(account: String) {
        SecItemDelete(query(account: account) as CFDictionary)
    }

    private static func query(account: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccessGroup as String: accessGroup,
        ]
        if let account { query[kSecAttrAccount as String] = account }
        return query
    }
}
