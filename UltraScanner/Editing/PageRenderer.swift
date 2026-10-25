import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Pure image operations behind Editar: filters, rotation and signatures. Everything runs
/// on-device (Core Image), no network.
enum PageRenderer {
    private static let context = CIContext()

    static func apply(_ filter: PageFilter, to image: UIImage) -> UIImage {
        guard filter != .original, let input = CIImage(image: image) else { return image }

        let output: CIImage?
        switch filter {
        case .original:
            output = input
        case .color:
            let f = CIFilter.colorControls()
            f.inputImage = input
            f.saturation = 1.15
            f.contrast = 1.1
            f.brightness = 0.02
            output = f.outputImage
        case .blackAndWhite:
            let f = CIFilter.colorControls()
            f.inputImage = input
            f.saturation = 0
            f.contrast = 1.35
            f.brightness = 0.05
            output = f.outputImage
        case .magic:
            // Apple's on-device document enhancer: evens out lighting and makes text crisp.
            let f = CIFilter.documentEnhancer()
            f.inputImage = input
            f.amount = 1
            output = f.outputImage
        }

        guard let output, let cgImage = context.createCGImage(output, from: input.extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    static func rotated(_ image: UIImage, quarterTurns: Int) -> UIImage {
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns != 0 else { return image }
        let size = turns % 2 == 0 ? image.size : CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: size.width / 2, y: size.height / 2)
            cg.rotate(by: CGFloat(turns) * .pi / 2)
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2,
                                  width: image.size.width, height: image.size.height))
        }
    }

    static func composite(_ signatures: [PlacedSignature], onto image: UIImage) -> UIImage {
        guard !signatures.isEmpty else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(at: .zero)
            for signature in signatures {
                signature.image.draw(in: signature.frame(in: image.size))
            }
        }
    }
}

/// A signature placed on a page. Position and width are fractions of the page, so the same
/// placement works on the small on-screen preview and on the full-resolution page.
struct PlacedSignature: Identifiable {
    let id = UUID()
    var image: UIImage
    var center: CGPoint
    var widthFraction: CGFloat

    func frame(in pageSize: CGSize) -> CGRect {
        let width = widthFraction * pageSize.width
        let height = width * image.size.height / max(image.size.width, 1)
        return CGRect(x: center.x * pageSize.width - width / 2,
                      y: center.y * pageSize.height - height / 2,
                      width: width, height: height)
    }
}
