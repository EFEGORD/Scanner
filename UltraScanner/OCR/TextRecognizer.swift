import Foundation
import Vision
import UIKit

/// Runs on-device OCR with Vision. Per product decision, there is no user-facing language
/// picker: we always recognize using the device's own language plus English, so documents
/// in either come back searchable without any setup.
enum TextRecognizer {
    static func recognitionLanguages() -> [String] {
        let deviceLanguage = Locale.preferredLanguages.first ?? "en-US"
        var seen = Set<String>()
        return [deviceLanguage, "en-US"].filter { seen.insert($0).inserted }
    }

    struct RecognizedLine {
        let text: String
        /// Normalized (0…1) with the origin at the bottom-left, as Vision returns it.
        let box: CGRect
    }

    /// Runs off the main thread so the UI keeps responding while a multi-page scan is read.
    static func recognizeText(in image: UIImage) async throws -> String {
        try await recognizeLines(in: image).map(\.text).joined(separator: "\n")
    }

    /// The lines with where they are on the page (for the PDF's invisible text layer).
    static func recognizeLines(in image: UIImage) async throws -> [RecognizedLine] {
        guard let cgImage = image.cgImage else { return [] }
        return try await Task.detached(priority: .userInitiated) { () -> [RecognizedLine] in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = recognitionLanguages()
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            return (request.results ?? []).compactMap { observation in
                observation.topCandidates(1).first.map { RecognizedLine(text: $0.string, box: observation.boundingBox) }
            }
        }.value
    }
}
