import Foundation
import UIKit

/// Ties the whole "guardar un escaneo nuevo" pipeline together:
/// cámara (VisionKit) → edición (filtros, rotar, firma) → OCR (Vision) → cifrado → base de datos.
/// Nothing here ever touches the network — every step is local.
@MainActor
final class ScanSessionViewModel: ObservableObject {
    @Published var pages: [PageEditState] = []
    @Published var isProcessing = false

    func addCapturedPages(_ images: [UIImage]) {
        pages.append(contentsOf: images.map { PageEditState(original: $0) })
    }

    /// Photos arrive cropped to the document found in them; the previews are made off the main thread.
    func addImportedPages(_ imported: [DocumentImporter.Page]) async {
        let states = await Task.detached(priority: .userInitiated) {
            imported.map { PageEditState(original: $0.image, crop: $0.crop) }
        }.value
        pages.append(contentsOf: states)
    }

    func removePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        pages.remove(at: index)
    }

    func movePage(at index: Int, by offset: Int) {
        let destination = index + offset
        guard pages.indices.contains(index), pages.indices.contains(destination) else { return }
        pages.swapAt(index, destination)
    }

    /// Renders every page with its edits, reads the text and stores everything encrypted as
    /// one new document.
    func saveAsDocument(title: String, folderId: String?) async throws -> ScanDocument {
        isProcessing = true
        defer { isProcessing = false }

        var scanPages: [ScanPage] = []
        for (index, page) in pages.enumerated() {
            let final = await Task.detached(priority: .userInitiated) { page.rendered() }.value
            scanPages.append(try await PageFactory.makePage(
                from: final, position: index, filter: page.filter, rotation: (page.quarterTurns % 4) * 90))
        }

        let document = try DocumentRepository.shared.createDocument(title: title, folderId: folderId, pages: scanPages)
        AppAnalytics.log(.scanSaved, ["pages": scanPages.count,
                                      "signed": pages.contains { !$0.signatures.isEmpty } ? 1 : 0])
        pages = []
        return document
    }
}
