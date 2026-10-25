import Foundation
import GRDB

struct ScanFolder: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "folders"

    var id: String
    var name: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
    }

    init(id: String = UUID().uuidString, name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
