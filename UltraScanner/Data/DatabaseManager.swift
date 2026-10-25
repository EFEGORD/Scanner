import Foundation
import GRDB

/// Owns the single SQLite connection for the whole app. The database lives only inside the
/// app sandbox — nothing here ever talks to a network.
///
/// Release builds encrypt the whole file (titles, folders, OCR text and the search index) with
/// SQLCipher, using a key that never leaves this device's Keychain, and keep it out of device
/// backups. Debug builds leave it unencrypted so it can be inspected while developing.
final class DatabaseManager {
    static let shared = DatabaseManager()

    let dbQueue: DatabaseQueue

    private init() {
        do {
            let fileURL = try Self.databaseURL()
            #if DEBUG
            if let plain = try? Self.open(fileURL, passphrase: nil) {
                dbQueue = plain
            } else {
                // A Release build already encrypted this file on the same phone.
                dbQueue = try Self.open(fileURL, passphrase: EncryptionManager.shared.databasePassphrase())
            }
            #else
            let passphrase = try EncryptionManager.shared.databasePassphrase()
            do {
                try Self.encryptPlaintextDatabase(at: fileURL, passphrase: passphrase)
            } catch {
                // Never leave the app crashing at launch: keep using the file as it is and
                // retry the move on the next launch.
                print("No se pudo cifrar la base de datos existente: \(error)")
            }
            dbQueue = try (try? Self.open(fileURL, passphrase: passphrase)) ?? Self.open(fileURL, passphrase: nil)
            #endif
            try Self.migrator.migrate(dbQueue)
            try Self.protectDatabaseFile(at: fileURL)
            #if !DEBUG
            try Self.excludeFromBackup(fileURL)
            #endif
        } catch {
            // There is no server fallback — surface it loudly rather than silently losing data.
            fatalError("No se pudo abrir la base de datos: \(error)")
        }
    }

    private static func databaseURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return documentsURL.appendingPathComponent("scanner.sqlite")
    }

    /// Opens the database, with the SQLCipher key when `passphrase` is given, and fails right
    /// away (instead of on the first query) if the key doesn't match the file.
    static func open(_ url: URL, passphrase: String?) throws -> DatabaseQueue {
        var config = Configuration()
        if let passphrase {
            config.prepareDatabase { db in
                try db.usePassphrase(passphrase)
            }
        }
        let queue = try DatabaseQueue(path: url.path, configuration: config)
        _ = try queue.read { db in try Int.fetchOne(db, sql: "SELECT count(*) FROM sqlite_master") }
        return queue
    }

    /// One-time move of an unencrypted database (from an earlier version of the app) into an
    /// encrypted one. Does nothing when the file is missing or already encrypted.
    static func encryptPlaintextDatabase(at url: URL, passphrase: String) throws {
        guard FileManager.default.fileExists(atPath: url.path),
              let plain = try? open(url, passphrase: nil) else { return }
        try plain.close()

        let encryptedURL = url.deletingLastPathComponent().appendingPathComponent("scanner.encrypting.sqlite")
        try? FileManager.default.removeItem(at: encryptedURL)
        let encrypted = try open(encryptedURL, passphrase: passphrase)
        try migrator.migrate(encrypted)
        try encrypted.writeWithoutTransaction { db in
            // KEY '' attaches the old file as plain SQLite.
            try db.execute(sql: "ATTACH DATABASE ? AS plain KEY ''", arguments: [url.path])
            try db.inTransaction {
                // Parents before children (foreign keys). The search index is rebuilt instead of
                // copied: its shadow tables are internal to FTS5.
                for table in ["folders", "documents", "tags", "pages", "document_tags",
                              "saved_signatures", "page_annotations", "settings"] {
                    try db.execute(sql: "INSERT INTO main.\(table) SELECT * FROM plain.\(table)")
                }
                try db.execute(sql: "INSERT INTO pages_fts(pages_fts) VALUES('rebuild')")
                return .commit
            }
            try db.execute(sql: "DETACH DATABASE plain")
        }
        try encrypted.close()
        _ = try FileManager.default.replaceItemAt(url, withItemAt: encryptedURL)
    }

    private static func protectDatabaseFile(at url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: url.path)
    }

    /// Product decision: no backups. If the phone is lost, the documents are lost too.
    static func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = url
        try url.setResourceValues(values)
    }

    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "folders") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("created_at", .datetime).notNull()
            }

            try db.create(table: "documents") { t in
                t.column("id", .text).primaryKey()
                t.column("title", .text).notNull()
                t.column("folder_id", .text).references("folders", onDelete: .setNull)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("export_format", .text).notNull().defaults(to: "pdf")
                t.column("thumbnail_path", .text)
            }

            try db.create(table: "pages") { t in
                t.column("id", .text).primaryKey()
                t.column("document_id", .text).notNull().references("documents", onDelete: .cascade)
                t.column("position", .integer).notNull()
                t.column("image_path", .text).notNull()
                t.column("thumb_path", .text).notNull()
                t.column("rotation", .integer).notNull().defaults(to: 0)
                t.column("filter", .text).notNull().defaults(to: "color")
                t.column("ocr_text", .text)
                t.column("ocr_lang", .text) // JSON-encoded array of language codes used
            }

            try db.create(table: "tags") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull().unique()
            }

            try db.create(table: "document_tags") { t in
                t.column("document_id", .text).notNull().references("documents", onDelete: .cascade)
                t.column("tag_id", .text).notNull().references("tags", onDelete: .cascade)
                t.primaryKey(["document_id", "tag_id"])
            }

            try db.create(table: "saved_signatures") { t in
                t.column("id", .text).primaryKey()
                t.column("image_path", .text).notNull()
                t.column("created_at", .datetime).notNull()
            }

            try db.create(table: "page_annotations") { t in
                t.column("id", .text).primaryKey()
                t.column("page_id", .text).notNull().references("pages", onDelete: .cascade)
                t.column("type", .text).notNull()
                t.column("asset_path", .text)
                t.column("x", .double).notNull()
                t.column("y", .double).notNull()
                t.column("w", .double).notNull()
                t.column("h", .double).notNull()
                t.column("rotation", .double).notNull().defaults(to: 0)
            }

            try db.create(table: "settings") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text)
            }

            // Full-text index over the OCR text so "búsqueda inteligente" is instant,
            // even with thousands of pages. Kept in sync with triggers below.
            try db.create(virtualTable: "pages_fts", using: FTS5()) { t in
                t.synchronize(withTable: "pages")
                t.column("ocr_text")
            }
        }

        return migrator
    }
}
