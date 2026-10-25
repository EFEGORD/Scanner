import UIKit

extension UIImage {
    func resized(toWidth width: CGFloat) -> UIImage {
        let scale = width / size.width
        return redrawn(to: CGSize(width: width, height: size.height * scale))
    }

    /// Smaller copy for on-screen previews; full-resolution images are only rendered at save time.
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let factor = maxDimension / longest
        return redrawn(to: CGSize(width: size.width * factor, height: size.height * factor))
    }

    private func redrawn(to newSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
