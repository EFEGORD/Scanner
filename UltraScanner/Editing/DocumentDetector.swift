import UIKit
import Vision

/// Finds the document in a photo (from Fotos or shared from another app) so it can be cropped and
/// straightened like a scan. Runs on-device (Vision), no network.
enum DocumentDetector {
    /// The document's corners, or nil when there's no clear document or it already fills the photo
    /// (a screenshot, a PDF page): then the photo is left whole.
    static func detect(in image: UIImage) -> PageQuad? {
        guard let cgImage = image.cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)

        let segmentation = VNDetectDocumentSegmentationRequest()
        let rectangles = VNDetectRectanglesRequest()
        rectangles.minimumSize = 0.3
        rectangles.minimumConfidence = 0.8
        rectangles.quadratureTolerance = 30
        rectangles.maximumObservations = 1

        for request in [segmentation, rectangles] as [VNImageBasedRequest] {
            try? handler.perform([request])
            guard let found = (request.results as? [VNRectangleObservation])?.first,
                  found.confidence >= 0.6 else { continue }
            // Vision's origin is bottom-left.
            func flipped(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x, y: 1 - point.y) }
            let quad = PageQuad(topLeft: flipped(found.topLeft), topRight: flipped(found.topRight),
                                bottomRight: flipped(found.bottomRight), bottomLeft: flipped(found.bottomLeft))
            if quad.area > 0.12 && quad.area < 0.92 && standsOut(quad, in: cgImage) { return quad }
        }
        return nil
    }

    /// Vision sometimes "finds" a document in a blank photo or a screenshot. A real one looks
    /// different from what's around it (a sheet on a table), so inside and outside are compared on
    /// a tiny gray copy of the photo.
    private static func standsOut(_ quad: PageQuad, in image: CGImage) -> Bool {
        let side = 48
        var pixels = [UInt8](repeating: 0, count: side * side)
        guard let context = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        let path = CGMutablePath()
        path.addLines(between: quad.corners.map { CGPoint(x: $0.x * CGFloat(side), y: $0.y * CGFloat(side)) })
        path.closeSubpath()
        var inside = (sum: 0.0, count: 0), outside = (sum: 0.0, count: 0)
        for row in 0..<side {
            for column in 0..<side {
                // The bitmap's first row is the top of the photo, like the quad.
                let value = Double(pixels[row * side + column]) / 255
                if path.contains(CGPoint(x: Double(column) + 0.5, y: Double(row) + 0.5)) {
                    inside.sum += value; inside.count += 1
                } else {
                    outside.sum += value; outside.count += 1
                }
            }
        }
        guard inside.count > 0, outside.count > 0 else { return false }
        return abs(inside.sum / Double(inside.count) - outside.sum / Double(outside.count)) > 0.08
    }
}
