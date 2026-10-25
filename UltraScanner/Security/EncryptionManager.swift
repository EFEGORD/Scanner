import Foundation
import CryptoKit

/// Generates and stores the device-bound encryption key, and encrypts/decrypts every file
/// the app writes (page images, thumbnails, saved signature). Nothing here ever calls out
/// to a network — the key is generated once, stored only in this device's Keychain/Secure
/// Enclave-backed storage, and used purely locally.
final class EncryptionManager {
    static let shared = EncryptionManager()

    // Never rename once published: the stored keys are found by this name, and without them
    // every saved document becomes unreadable.
    private static let service = "mx.com.claudita.ultrascanner.encryption"
    private static let fileKeyAccount = "file-encryption-key"
    private static let dbKeyAccount = "database-passphrase"

    private let fileKey: SymmetricKey

    private init() {
        fileKey = Self.loadOrCreateKey(account: Self.fileKeyAccount)
    }

    /// AES-256 key, created once on first launch, never exported, never synced to iCloud.
    private static func loadOrCreateKey(account: String) -> SymmetricKey {
        if let existing = try? KeychainHelper.load(service: service, account: account) {
            return SymmetricKey(data: existing)
        }
        let newKey = SymmetricKey(size: .bits256)
        let data = newKey.withUnsafeBytes { Data($0) }
        try? KeychainHelper.save(data, service: service, account: account)
        return newKey
    }

    /// Passphrase SQLCipher uses to encrypt the whole metadata/OCR-text database.
    /// Stored separately from the file key so each layer can be rotated independently later.
    func databasePassphrase() throws -> String {
        if let existing = try KeychainHelper.load(service: Self.service, account: Self.dbKeyAccount),
           let string = String(data: existing, encoding: .utf8) {
            return string
        }
        let passphrase = UUID().uuidString + UUID().uuidString
        try KeychainHelper.save(Data(passphrase.utf8), service: Self.service, account: Self.dbKeyAccount)
        return passphrase
    }

    // MARK: - File encryption (page images, thumbnails, saved signature)

    func encrypt(_ plaintext: Data) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: fileKey)
        guard let combined = sealed.combined else {
            throw EncryptionError.sealingFailed
        }
        return combined
    }

    func decrypt(_ ciphertext: Data) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(box, using: fileKey)
    }

    enum EncryptionError: Error {
        case sealingFailed
    }
}
