import Foundation

/// Writes/reads page images and thumbnails as encrypted blobs under the app's Documents
/// directory. Callers always work with plain `Data` (decrypted) in memory; an unencrypted
/// copy never touches disk except for the short-lived temporary export file that is handed
/// to the share sheet and deleted right after (see ExportService).
final class SecureFileStore {
    static let shared = SecureFileStore()

    let rootURL: URL

    private init() {
        let documents = try! FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        rootURL = documents.appendingPathComponent("pages", isDirectory: true)
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        #if !DEBUG
        // Product decision: no backups. (The images are encrypted with a key that never leaves
        // this phone, so a backup of them would be unreadable anyway.)
        try? DatabaseManager.excludeFromBackup(rootURL)
        #endif
    }

    /// Returns a path (relative, stored in the DB) for a brand-new encrypted file.
    func newRelativePath(extension ext: String = "bin") -> String {
        "\(UUID().uuidString).\(ext)"
    }

    func write(_ plaintext: Data, relativePath: String) throws {
        let encrypted = try EncryptionManager.shared.encrypt(plaintext)
        let url = rootURL.appendingPathComponent(relativePath)
        // Second, OS-level layer on top of our AES-GCM encryption, tied to the device passcode.
        try encrypted.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    func read(relativePath: String) throws -> Data {
        let url = rootURL.appendingPathComponent(relativePath)
        let encrypted = try Data(contentsOf: url)
        return try EncryptionManager.shared.decrypt(encrypted)
    }

    /// Copies an encrypted file as-is (no decryption) and returns the new relative path —
    /// used when a page is reused in a combined document, so the original stays untouched.
    func copy(relativePath: String) throws -> String {
        let ext = (relativePath as NSString).pathExtension
        let newPath = newRelativePath(extension: ext.isEmpty ? "bin" : ext)
        try FileManager.default.copyItem(
            at: rootURL.appendingPathComponent(relativePath),
            to: rootURL.appendingPathComponent(newPath))
        return newPath
    }

    func exists(relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(relativePath).path)
    }

    func delete(relativePath: String) {
        let url = rootURL.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: url)
    }
}
