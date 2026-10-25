import SwiftUI

/// Shows an image stored encrypted by SecureFileStore. Decrypts off the main thread and
/// keeps the plaintext only in memory.
struct SecureImageView: View {
    let relativePath: String?
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color.accentColor.opacity(0.12)
            }
        }
        .task(id: relativePath) { await load() }
    }

    private func load() async {
        guard let relativePath else {
            image = nil
            return
        }
        image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? SecureFileStore.shared.read(relativePath: relativePath) else { return nil }
            return UIImage(data: data)
        }.value
    }
}
