import Foundation
import GRDB

struct ScanTag: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "tags"

    var id: String
    var name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}

/// Join row for the many-to-many documents <-> tags relationship.
struct DocumentTag: Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "document_tags"

    var documentId: String
    var tagId: String

    enum CodingKeys: String, CodingKey {
        case documentId = "document_id"
        case tagId = "tag_id"
    }
}
