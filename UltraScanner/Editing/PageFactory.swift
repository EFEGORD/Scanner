import UIKit

/// Turns images into stored pages: OCR + encryption, off the main thread.
enum PageFactory {
    enum PageFactoryError: Error {
        case encodingFailed
    }

    /// Reads the text and writes the encrypted image + thumbnail. The page still has to be
    /// inserted in a document (DocumentRepository.createDocument).
    static func makePage(from image: UIImage, position: Int, filter: PageFilter = .original,
                         rotation: Int = 0) async throws -> ScanPage {
        let ocrText = try? await TextRecognizer.recognizeText(in: image)
        return try await Task.detached(priority: .userInitiated) { () -> ScanPage in
            let store = SecureFileStore.shared
            guard let full = image.jpegData(compressionQuality: 1.0),
                  let thumb = image.resized(toWidth: 240).jpegData(compressionQuality: 0.8) else {
                throw PageFactoryError.encodingFailed
            }
            let imagePath = store.newRelativePath(extension: "jpg")
            let thumbPath = store.newRelativePath(extension: "jpg")
            try store.write(full, relativePath: imagePath)
            try store.write(thumb, relativePath: thumbPath)
            return ScanPage(documentId: "", position: position, imagePath: imagePath, thumbPath: thumbPath,
                            rotation: rotation, filter: filter, ocrText: ocrText,
                            ocrLanguages: TextRecognizer.recognitionLanguages())
        }.value
    }

    /// A copy of an existing page for a combined document: the encrypted files are duplicated
    /// byte for byte (no decryption), so the original document keeps its own pages.
    static func duplicate(_ page: ScanPage, position: Int) throws -> ScanPage {
        let store = SecureFileStore.shared
        let imagePath = try store.copy(relativePath: page.imagePath)
        let thumbPath = try store.copy(relativePath: page.thumbPath)
        return ScanPage(documentId: "", position: position, imagePath: imagePath, thumbPath: thumbPath,
                        rotation: page.rotation, filter: page.filter, ocrText: page.ocrText,
                        ocrLanguages: page.ocrLanguages)
    }

    /// Decrypts a stored page image for editing.
    static func loadImage(of page: ScanPage) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? SecureFileStore.shared.read(relativePath: page.imagePath) else { return nil }
            return UIImage(data: data)
        }.value
    }
}
