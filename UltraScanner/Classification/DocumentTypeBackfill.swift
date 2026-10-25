import Foundation

/// Recognizes the type of pages saved before the app knew about document types. Runs once in
/// the background after launch; pages saved from now on are classified when they're saved.
enum DocumentTypeBackfill {
    static func run() async {
        guard let pages = try? DocumentRepository.shared.pagesNeedingClassification(), !pages.isEmpty else { return }
        for page in pages {
            var barcodes: [String] = []
            if let image = await PageFactory.loadImage(of: page) {
                barcodes = await BarcodeReader.payloads(in: image)
            }
            let detected = DocumentClassifier.classify(text: page.ocrText ?? "", barcodes: barcodes)
            try? DocumentRepository.shared.updateClassification(pageId: page.id, documents: detected)
        }
    }
}
