import Foundation
import GRDB

struct ScanDocument: Identifiable, Codable, Hashable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "documents"

    var id: String
    var title: String
    var folderId: String?
    var createdAt: Date
    var updatedAt: Date
    var exportFormat: ExportFormat
    var thumbnailPath: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case folderId = "folder_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case exportFormat = "export_format"
        case thumbnailPath = "thumbnail_path"
    }

    init(id: String = UUID().uuidString,
         title: String,
         folderId: String? = nil,
         createdAt: Date = Date(),
         updatedAt: Date = Date(),
         exportFormat: ExportFormat = .pdf,
         thumbnailPath: String? = nil) {
        self.id = id
        self.title = title
        self.folderId = folderId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.exportFormat = exportFormat
        self.thumbnailPath = thumbnailPath
    }
}

enum ExportFormat: String, Codable, DatabaseValueConvertible {
    case pdf
    case jpg
}

extension ScanDocument {
    static let pages = hasMany(ScanPage.self)
    static let tags = hasMany(DocumentTag.self)

    var pages: QueryInterfaceRequest<ScanPage> {
        request(for: ScanDocument.pages).order(Column("position"))
    }
}
