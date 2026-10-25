import Foundation
import GRDB

/// Owns the single encrypted SQLite connection (SQLCipher) for the whole app.
/// The database lives only inside the app sandbox — nothing here ever talks to a network.
final class DatabaseManager {
    static let shared = DatabaseManager()

    let dbQueue: DatabaseQueue

    private init() {
        do {
            let fileURL = try Self.databaseURL()
            let config = Configuration()

            // NOTE — encryption TODO before shipping: GRDB's default Swift Package Manager
            // build links the system sqlite3, which has no SQLCipher support, so
            // `db.usePassphrase(...)` isn't available yet. For this first build we rely on
            // iOS Data Protection (NSFileProtectionComplete, set right below) to keep the
            // database encrypted at rest. To add the second, app-level layer described in
            // the design conversation, follow "Cifrado de la base de datos (SQLCipher)" in
            // SETUP.md, then uncomment a `prepareDatabase` block here that calls
            // `db.usePassphrase(try EncryptionManager.shared.databasePassphrase())`.

            dbQueue = try DatabaseQueue(path: fileURL.path, configuration: config)
            try Self.migrator.migrate(dbQueue)
            try Self.protectDatabaseFile(at: fileURL)
        } catch {
            // A failure here means the encrypted store could not be opened or created.
            // There is no server fallback — surface it loudly rather than silently losing data.
            fatalError("No se pudo abrir la base de datos cifrada: \(error)")
        }
    }

    private static func databaseURL() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return documentsURL.appendingPathComponent("scanner.sqlite")
    }

    private static func protectDatabaseFile(at url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: url.path)
    }

    private static var migrator: DatabaseMigrator {
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
