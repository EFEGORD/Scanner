import Foundation
import Vision
import UIKit

/// Runs on-device OCR with Vision. Per product decision, there is no user-facing language
/// picker: we always recognize using the device's own language plus English, so documents
/// in either come back searchable without any setup.
enum TextRecognizer {
    static func recognitionLanguages() -> [String] {
        let deviceLanguage = Locale.preferredLanguages.first ?? "en-US"
        let languages = [deviceLanguage, "en-US"]
        // De-dup while preserving order (e.g. device already in English).
        var seen = Set<String>()
        return languages.filter { seen.insert($0).inserted }
    }

    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = recognitionLanguages()

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
