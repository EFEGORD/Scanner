import Foundation
import GRDB

/// A signature the user drew once and can reuse across documents without redrawing it.
struct SavedSignature: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "saved_signatures"

    var id: String
    /// Path to the encrypted PNG (transparent background) inside the app's secure store.
    var imagePath: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case imagePath = "image_path"
        case createdAt = "created_at"
    }

    init(id: String = UUID().uuidString, imagePath: String, createdAt: Date = Date()) {
        self.id = id
        self.imagePath = imagePath
        self.createdAt = createdAt
    }
}

/// A signature/annotation instance placed on a specific page.
struct PageAnnotation: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "page_annotations"

    var id: String
    var pageId: String
    var type: AnnotationType
    var assetPath: String?
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var rotation: Double

    enum CodingKeys: String, CodingKey {
        case id
        case pageId = "page_id"
        case type
        case assetPath = "asset_path"
        case x, y, width = "w", height = "h", rotation
    }

    init(id: String = UUID().uuidString,
         pageId: String,
         type: AnnotationType,
         assetPath: String? = nil,
         x: Double, y: Double, width: Double, height: Double, rotation: Double = 0) {
        self.id = id
        self.pageId = pageId
        self.type = type
        self.assetPath = assetPath
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = rotation
    }
}

enum AnnotationType: String, Codable, DatabaseValueConvertible {
    case signature
    case text
    case highlight
}
