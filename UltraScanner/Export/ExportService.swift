import Foundation
import PDFKit
import UIKit

/// Builds the plaintext file(s) handed to the iOS share sheet. This is the ONLY place a
/// decrypted copy ever touches disk: it goes to a temporary folder and `cleanUp` deletes it
/// as soon as the share sheet closes. What the user shares after that is up to them.
enum ExportService {
    enum ExportError: Error {
        case pdfFailed
        case jpegFailed
    }

    static func makeShareFiles(for document: ScanDocument, format: ExportFormat) throws -> [URL] {
        let pages = try DocumentRepository.shared.pages(of: document.id)
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("share-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let baseName = sanitizedFileName(document.title)

        let decrypted: [(image: UIImage, ocrText: String?)] = try pages.compactMap { page -> (image: UIImage, ocrText: String?)? in
            let data = try SecureFileStore.shared.read(relativePath: page.imagePath)
            guard let image = UIImage(data: data) else { return nil }
            return (image: image, ocrText: page.ocrText)
        }

        switch format {
        case .pdf:
            let pdf = PDFGenerator.makePDF(pages: decrypted)
            guard let data = pdf.dataRepresentation() else { throw ExportError.pdfFailed }
            let url = folder.appendingPathComponent("\(baseName).pdf")
            try data.write(to: url, options: .completeFileProtection)
            return [url]

        case .jpg:
            var urls: [URL] = []
            for (index, entry) in decrypted.enumerated() {
                guard let data = entry.image.jpegData(compressionQuality: 1.0) else { throw ExportError.jpegFailed }
                let suffix = decrypted.count > 1 ? " - \(index + 1)" : ""
                let url = folder.appendingPathComponent("\(baseName)\(suffix).jpg")
                try data.write(to: url, options: .completeFileProtection)
                urls.append(url)
            }
            return urls
        }
    }

    static func cleanUp(_ urls: [URL]) {
        let folders = Set(urls.map { $0.deletingLastPathComponent() })
        for folder in folders {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    private static func sanitizedFileName(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = title
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Documento" : cleaned
    }
}
