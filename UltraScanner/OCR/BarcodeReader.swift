import UIKit
import Vision

/// Reads the barcodes on a page (PDF417 of US licenses, QR of the INE…) on-device. Used only to
/// recognize the document type: the contents are not stored.
enum BarcodeReader {
    static func payloads(in image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        return await Task.detached(priority: .userInitiated) { () -> [String] in
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.pdf417, .qr, .aztec]
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            return (request.results ?? []).compactMap { $0.payloadStringValue }
        }.value
    }
}
