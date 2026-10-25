import Foundation
import GRDB

struct ScanPage: Identifiable, Codable, Equatable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "pages"

    var id: String
    var documentId: String
    var position: Int
    /// Relative path (inside the app's encrypted store) to the processed, ENCRYPTED page image.
    var imagePath: String
    var thumbPath: String
    var rotation: Int
    var filter: PageFilter
    /// Extracted by Vision OCR. Stored in the encrypted SQLite file (SQLCipher), never in plain text on disk.
    var ocrText: String?
    var ocrLanguages: [String]?
    /// Detected document types, e.g. "ine.back,passport" (see DocumentClassifier.encode).
    /// nil = not analyzed yet; "" = analyzed, nothing recognized.
    var docTypes: String?
    /// Search words for those types, in Spanish and English ("ine reverso identificacion id…"),
    /// indexed by the search next to the OCR text.
    var docTags: String?

    enum CodingKeys: String, CodingKey {
        case id
        case documentId = "document_id"
        case position
        case imagePath = "image_path"
        case thumbPath = "thumb_path"
        case rotation
        case filter
        case ocrText = "ocr_text"
        case ocrLanguages = "ocr_lang"
        case docTypes = "doc_types"
        case docTags = "doc_tags"
    }

    init(id: String = UUID().uuidString,
         documentId: String,
         position: Int,
         imagePath: String,
         thumbPath: String,
         rotation: Int = 0,
         filter: PageFilter = .color,
         ocrText: String? = nil,
         ocrLanguages: [String]? = nil,
         docTypes: String? = nil,
         docTags: String? = nil) {
        self.id = id
        self.documentId = documentId
        self.position = position
        self.imagePath = imagePath
        self.thumbPath = thumbPath
        self.rotation = rotation
        self.filter = filter
        self.ocrText = ocrText
        self.ocrLanguages = ocrLanguages
        self.docTypes = docTypes
        self.docTags = docTags
    }

    var detectedDocuments: [DetectedDocument] {
        DocumentClassifier.decode(docTypes)
    }

    /// "INE · reverso", "Pasaporte", … or nil when the page's type wasn't recognized.
    var documentLabel: String? {
        DocumentClassifier.label(for: detectedDocuments)
    }
}

enum PageFilter: String, Codable, DatabaseValueConvertible {
    case color
    case blackAndWhite = "bw"
    case magic
    case original
}
