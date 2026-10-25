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

    func createDocument(title: String, folderId: String?, pages: [ScanPage]) throws -> ScanDocument {
        try dbQueue.write { db in
            var document = ScanDocument(title: title, folderId: folderId)
            try document.insert(db)
            for page in pages {
                var p = page
                p.documentId = document.id
                try p.insert(db)
            }
            return document
        }
    }

    func deleteDocument(id: String) throws {
        _ = try dbQueue.write { db in
            try ScanDocument.deleteOne(db, key: id)
        }
    }

    // MARK: - Dividir / combinar (ver modelo de datos del canvas)

    /// Mueve un rango de páginas a un documento nuevo, reordenando lo que queda.
    func splitDocument(_ documentId: String, afterPosition: Int, newTitle: String) throws -> ScanDocument {
        try dbQueue.write { db in
            let original = try ScanDocument.fetchOne(db, key: documentId)!
            var newDoc = ScanDocument(title: newTitle, folderId: original.folderId)
            try newDoc.insert(db)

            let movingPages = try ScanPage
                .filter(Column("document_id") == documentId && Column("position") > afterPosition)
                .order(Column("position"))
                .fetchAll(db)

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

    struct SearchHit {
        let document: ScanDocument
        let page: ScanPage
        let snippet: String
    }

    func search(_ query: String) throws -> [SearchHit] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return try dbQueue.read { db in
            let sql = """
                SELECT pages.*, snippet(pages_fts, 0, '', '', '…', 10) AS snippet
                FROM pages_fts
                JOIN pages ON pages.id = pages_fts.rowid
                WHERE pages_fts MATCH ?
                ORDER BY rank
                LIMIT 50
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: [query + "*"])
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
            var folder = ScanFolder(name: name)
            try folder.insert(db)
            return folder
        }
    }

    // MARK: - Firma guardada

    func savedSignature() throws -> SavedSignature? {
        try dbQueue.read { db in try SavedSignature.order(Column("created_at").desc).fetchOne(db) }
    }

    func saveSignature(_ signature: SavedSignature) throws {
        _ = try dbQueue.write { db in try signature.insert(db) }
    }
}
