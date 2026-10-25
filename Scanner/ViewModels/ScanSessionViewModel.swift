import Foundation
import UIKit

/// Ties the whole "guardar un escaneo nuevo" pipeline together:
/// cámara (VisionKit) → OCR (Vision) → cifrado (EncryptionManager/SecureFileStore) → base de datos (GRDB).
/// Nothing here ever touches the network — every step is local.
@MainActor
final class ScanSessionViewModel: ObservableObject {
    @Published var capturedImages: [UIImage] = []
    @Published var isProcessing = false

    private let repository = DocumentRepository.shared
    private let fileStore = SecureFileStore.shared

    func addCapturedPages(_ images: [UIImage]) {
        capturedImages.append(contentsOf: images)
    }

    func removePage(at index: Int) {
        guard capturedImages.indices.contains(index) else { return }
        capturedImages.remove(at: index)
    }

    func movePage(from source: Int, to destination: Int) {
        guard capturedImages.indices.contains(source) else { return }
        let image = capturedImages.remove(at: source)
        capturedImages.insert(image, at: min(destination, capturedImages.count))
    }

    /// Runs OCR on every page, encrypts the images, and writes everything to the
    /// encrypted database as a single new document.
    func saveAsDocument(title: String, folderId: String?) async throws -> ScanDocument {
        isProcessing = true
        defer { isProcessing = false }

        var pages: [ScanPage] = []
        for (index, image) in capturedImages.enumerated() {
            let ocrText = try? await TextRecognizer.recognizeText(in: image)

            let imagePath = fileStore.newRelativePath(extension: "jpg")
            let thumbPath = fileStore.newRelativePath(extension: "jpg")
            guard let fullData = image.jpegData(compressionQuality: 1.0),
                  let thumbImage = image.resized(toWidth: 160),
                  let thumbData = thumbImage.jpegData(compressionQuality: 0.8) else {
                continue
            }
            try fileStore.write(fullData, relativePath: imagePath)
            try fileStore.write(thumbData, relativePath: thumbPath)

            pages.append(ScanPage(
                documentId: "", // filled in by createDocument
                position: index,
                imagePath: imagePath,
                thumbPath: thumbPath,
                ocrText: ocrText,
                ocrLanguages: TextRecognizer.recognitionLanguages()
            ))
        }

        let document = try repository.createDocument(title: title, folderId: folderId, pages: pages)
        capturedImages = []
        return document
    }
}

private extension UIImage {
    func resized(toWidth width: CGFloat) -> UIImage? {
        let scale = width / size.width
        let newSize = CGSize(width: width, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
