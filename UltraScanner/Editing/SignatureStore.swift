import UIKit

/// The one signature the user can reuse, stored encrypted like the pages.
enum SignatureStore {
    static func loadSaved() -> UIImage? {
        guard let signature = try? DocumentRepository.shared.savedSignature(),
              let data = try? SecureFileStore.shared.read(relativePath: signature.imagePath) else { return nil }
        return UIImage(data: data)
    }

    static func save(_ image: UIImage) {
        guard let data = image.pngData() else { return }
        let path = SecureFileStore.shared.newRelativePath(extension: "png")
        do {
            try SecureFileStore.shared.write(data, relativePath: path)
            try DocumentRepository.shared.replaceSavedSignature(with: SavedSignature(imagePath: path))
        } catch {
            SecureFileStore.shared.delete(relativePath: path)
        }
    }

    static func deleteSaved() {
        try? DocumentRepository.shared.deleteSavedSignatures()
    }
}
