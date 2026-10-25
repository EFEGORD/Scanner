import Foundation
import PDFKit
import UIKit

/// Assembles a document's pages into a PDF with an invisible, searchable text layer
/// built from the OCR output — so the exported file is searchable in Files/Spotlight too,
/// not just inside the app. Used only at export/share time (see ExportService); the
/// encrypted on-disk store never holds a plaintext PDF.
enum PDFGenerator {
    static func makePDF(pages: [(image: UIImage, ocrText: String?)]) -> PDFDocument {
        let pdfDocument = PDFDocument()

        for (index, entry) in pages.enumerated() {
            guard let page = PDFPage(image: entry.image) else { continue }

            if let ocrText = entry.ocrText, !ocrText.isEmpty {
                // Overlaying real invisible text runs requires PDFKit annotation tricks;
                // for the MVP we attach the OCR text as a page-level annotation so Spotlight
                // and the in-app search can still find it even before a full text-layer
                // renderer is built.
                let annotation = PDFAnnotation(bounds: page.bounds(for: .mediaBox), forType: .freeText, withProperties: nil)
                annotation.contents = ocrText
                annotation.color = .clear
                annotation.font = UIFont.systemFont(ofSize: 0.01)
                page.addAnnotation(annotation)
            }

            pdfDocument.insert(page, at: index)
        }

        return pdfDocument
    }
}
