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

    /// Runs off the main thread so the UI keeps responding while a multi-page scan is read.
    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }
        return try await Task.detached(priority: .userInitiated) { () -> String in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = recognitionLanguages()
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            return (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }.value
    }
}
