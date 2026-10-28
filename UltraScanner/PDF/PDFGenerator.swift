import CoreText
import Foundation
import UIKit

/// Assembles a document's pages into a PDF with an invisible, searchable text layer: each
/// recognized line is drawn in invisible text mode right over where it appears on the page, so
/// the exported file can be searched, selected and copied in any viewer (Files, Spotlight,
/// Acrobat…) and nothing extra shows on screen or in print. Used only at export/share time (see
/// ExportService); the encrypted on-disk store never holds a plaintext PDF.
enum PDFGenerator {
    /// Pages are letter width (8.5 in) with the scan's proportions, so they print at a normal
    /// size; the image keeps its full resolution inside.
    static let pageWidth: CGFloat = 612

    static func makePDF(pages: [(image: UIImage, lines: [TextRecognizer.RecognizedLine])]) -> Data {
        let first = pageBounds(for: pages.first?.image)
        return UIGraphicsPDFRenderer(bounds: first).pdfData { context in
            for page in pages {
                let bounds = pageBounds(for: page.image)
                context.beginPage(withBounds: bounds, pageInfo: [:])
                page.image.draw(in: bounds)
                drawInvisible(page.lines, in: bounds, on: context.cgContext)
            }
        }
    }

    private static func pageBounds(for image: UIImage?) -> CGRect {
        guard let size = image?.size, size.width > 0 else { return CGRect(x: 0, y: 0, width: pageWidth, height: 792) }
        return CGRect(x: 0, y: 0, width: pageWidth, height: pageWidth * size.height / size.width)
    }

    private static func drawInvisible(_ lines: [TextRecognizer.RecognizedLine], in bounds: CGRect, on context: CGContext) {
        context.saveGState()
        context.setTextDrawingMode(.invisible)
        context.textMatrix = .identity
        for line in lines where !line.text.isEmpty {
            // Vision's box is normalized from the bottom-left; the PDF context is UIKit's (top-left).
            let rect = CGRect(x: line.box.minX * bounds.width, y: (1 - line.box.maxY) * bounds.height,
                              width: line.box.width * bounds.width, height: line.box.height * bounds.height)
            guard rect.width > 1, rect.height > 1 else { continue }
            let font = UIFont.systemFont(ofSize: rect.height * 0.8)
            let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: line.text, attributes: [.font: font]))
            let width = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
            guard width > 0 else { continue }
            context.saveGState()
            // Baseline near the bottom of the box; stretched to the box's width so selecting a
            // word highlights that word. y is flipped back so CoreText draws upright.
            context.translateBy(x: rect.minX, y: rect.maxY + font.descender * 0.8)
            context.scaleBy(x: rect.width / width, y: -1)
            context.textPosition = .zero
            CTLineDraw(ctLine, context)
            context.restoreGState()
        }
        context.restoreGState()
    }
}
