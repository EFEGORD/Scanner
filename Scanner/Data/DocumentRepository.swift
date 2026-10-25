import Foundation
import GRDB

/// Single point of access to documents/pages/folders. Views and ViewModels never touch
/// GRDB or the file system directly — everything goes through here, so storage or
/// encryption details can change without touching UI code.
final class DocumentRepository {
    static let shared = DocumentRepository()

    private var dbQueue: DatabaseQueue { DatabaseManager.shared.dbQueue }

    // MARK: - Documents

    func allDocuments(inFolder folderId: String? = nil) throws -> [ScanDocument] {
        try dbQueue.read { db in
            var request = ScanDocument.order(Column("updated_at").desc)
            if let folderId {
                request = request.filter(Column("folder_id") == folderId)
            }
            return try request.fetchAll(db)
        }
    }

    func document(id: String) throws -> ScanDocument? {
        try dbQueue.read { db in try ScanDocument.fetchOne(db, key: id) }
    }

    func pages(of documentId: String) throws -> [ScanPage] {
        try dbQueue.read { db in
            try ScanPage
                .filter(Column("document_id") == documentId)
                .order(Column("position"))
                .fetchAll(db)
        }
    }

    /// Page count per document id, in one query (for the Biblioteca rows).
    func pageCounts() throws -> [String: Int] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT document_id, COUNT(*) AS n FROM pages GROUP BY document_id")
            var counts: [String: Int] = [:]
            for row in rows {
                let documentId: String = row["document_id"]
                let count: Int = row["n"]
                counts[documentId] = count
            }
            return counts
        }
    }

    func createDocument(title: String, folderId: String?, pages: [ScanPage]) throws -> ScanDocument {
        try dbQueue.write { db in
            let cover = pages.min(by: { $0.position < $1.position })?.thumbPath
            let document = ScanDocument(title: title, folderId: folderId, thumbnailPath: cover)
            try document.insert(db)
            for page in pages {
                var p = page
                p.documentId = document.id
                try p.insert(db)
            }
            return document
        }
    }

    func renameDocument(id: String, to title: String) throws {
        try dbQueue.write { db in
            guard var document = try ScanDocument.fetchOne(db, key: id) else { return }
            document.title = title
            document.updatedAt = Date()
            try document.update(db)
        }
    }

    func moveDocument(id: String, toFolder folderId: String?) throws {
        try dbQueue.write { db in
            guard var document = try ScanDocument.fetchOne(db, key: id) else { return }
            document.folderId = folderId
            document.updatedAt = Date()
            try document.update(db)
        }
    }

    /// Deletes the rows AND the encrypted image files — a deleted document must not leave
    /// page images behind on disk.
    func deleteDocument(id: String) throws {
        let pages = try self.pages(of: id)
        _ = try dbQueue.write { db in
            try ScanDocument.deleteOne(db, key: id)
        }
        for page in pages {
            SecureFileStore.shared.delete(relativePath: page.imagePath)
            SecureFileStore.shared.delete(relativePath: page.thumbPath)
        }
    }

    // MARK: - Dividir / combinar (ver modelo de datos del canvas)

    /// Mueve un rango de páginas a un documento nuevo, reordenando lo que queda.
    func splitDocument(_ documentId: String, afterPosition: Int, newTitle: String) throws -> ScanDocument {
        try dbQueue.write { db in
            let original = try ScanDocument.fetchOne(db, key: documentId)!
            let movingPages = try ScanPage
                .filter(Column("document_id") == documentId && Column("position") > afterPosition)
                .order(Column("position"))
                .fetchAll(db)

            let newDoc = ScanDocument(title: newTitle, folderId: original.folderId,
                                      thumbnailPath: movingPages.first?.thumbPath)
            try newDoc.insert(db)

            for (index, page) in movingPages.enumerated() {
                var p = page
                p.documentId = newDoc.id
                p.position = index
                try p.update(db)
            }
            return newDoc
        }
    }

    /// Combina páginas de un documento origen dentro de un documento destino, al final.
    func mergePages(from sourceDocumentId: String, into targetDocumentId: String) throws {
        try dbQueue.write { db in
            let targetCount = try ScanPage
                .filter(Column("document_id") == targetDocumentId)
                .fetchCount(db)

            let sourcePages = try ScanPage
                .filter(Column("document_id") == sourceDocumentId)
                .order(Column("position"))
                .fetchAll(db)

            for (offset, page) in sourcePages.enumerated() {
                var p = page
                p.documentId = targetDocumentId
                p.position = targetCount + offset
                try p.update(db)
            }

            // El documento origen quedó vacío: se elimina.
            try ScanDocument.deleteOne(db, key: sourceDocumentId)
        }
    }

    // MARK: - Búsqueda inteligente (texto OCR)

    /// Turns what the user typed into a safe FTS5 query: every word must appear, each as a
    /// prefix ("fact marz" finds "factura de marzo"). Punctuation is dropped, so input like
    /// `luz-octubre` or `"INE:"` never reaches FTS5 as broken syntax.
    static func ftsMatchExpression(for query: String) -> String? {
        let words = query
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }
        return words.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    struct SearchHit {
        let document: ScanDocument
        let page: ScanPage
        let snippet: String
    }

    func search(_ query: String) throws -> [SearchHit] {
        guard let match = Self.ftsMatchExpression(for: query) else { return [] }
        return try dbQueue.read { db in
            // pages.id is a UUID string; the FTS index is keyed by the pages table's integer rowid.
            let sql = """
                SELECT pages.*, snippet(pages_fts, 0, '', '', '…', 10) AS snippet
                FROM pages_fts
                JOIN pages ON pages.rowid = pages_fts.rowid
                WHERE pages_fts MATCH ?
                ORDER BY rank
                LIMIT 50
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: [match])
            return try rows.compactMap { row in
                let page = try ScanPage(row: row)
                guard let document = try ScanDocument.fetchOne(db, key: page.documentId) else { return nil }
                let snippet: String = row["snippet"] ?? ""
                return SearchHit(document: document, page: page, snippet: snippet)
            }
        }
    }

    // MARK: - Carpetas

    func allFolders() throws -> [ScanFolder] {
        try dbQueue.read { db in try ScanFolder.order(Column("name")).fetchAll(db) }
    }

    func createFolder(name: String) throws -> ScanFolder {
        try dbQueue.write { db in
            let folder = ScanFolder(name: name)
            try folder.insert(db)
            return folder
        }
    }

    /// Documents in the folder are kept; the foreign key sets their folder_id to NULL.
    func deleteFolder(id: String) throws {
        _ = try dbQueue.write { db in try ScanFolder.deleteOne(db, key: id) }
    }

    // MARK: - Firma guardada

    func savedSignature() throws -> SavedSignature? {
        try dbQueue.read { db in try SavedSignature.order(Column("created_at").desc).fetchOne(db) }
    }

    func saveSignature(_ signature: SavedSignature) throws {
        _ = try dbQueue.write { db in try signature.insert(db) }
    }
}
