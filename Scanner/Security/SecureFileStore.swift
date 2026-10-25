import Foundation

/// Writes/reads page images and thumbnails as encrypted blobs under the app's Documents
/// directory. Callers always work with plain `Data` (decrypted) in memory; an unencrypted
/// copy never touches disk except for the short-lived temporary export file that is handed
/// to the share sheet and deleted right after (see ExportService).
final class SecureFileStore {
    static let shared = SecureFileStore()

    private let rootURL: URL

    private init() {
        let documents = try! FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        rootURL = documents.appendingPathComponent("pages", isDirectory: true)
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    /// Returns a path (relative, stored in the DB) for a brand-new encrypted file.
    func newRelativePath(extension ext: String = "bin") -> String {
        "\(UUID().uuidString).\(ext)"
    }

    func write(_ plaintext: Data, relativePath: String) throws {
        let encrypted = try EncryptionManager.shared.encrypt(plaintext)
        let url = rootURL.appendingPathComponent(relativePath)
        try encrypted.write(to: url, options: .completeFileProtectionUnlessOpen)
    }

    func read(relativePath: String) throws -> Data {
        let url = rootURL.appendingPathComponent(relativePath)
        let encrypted = try Data(contentsOf: url)
        return try EncryptionManager.shared.decrypt(encrypted)
    }

    func delete(relativePath: String) {
        let url = rootURL.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: url)
    }
}

private extension Data.WritingOptions {
    /// Maps to NSFileProtectionCompleteUnlessOpen — a second, OS-level layer on top of our
    /// own AES-GCM encryption, tied to the device passcode.
    static var completeFileProtectionUnlessOpen: Data.WritingOptions {
        Data.WritingOptions(rawValue: 1 << 17) // .completeFileProtectionUnlessOpen
    }
}
