import Foundation

/// Where the share extension ("Compartir" › UltraScanner in Fotos, WhatsApp, Mail, Archivos…)
/// leaves the photos and PDFs it receives, for the app to import. It lives in the App Group both
/// targets share. Each share is one folder ("batch"): the extension writes it under a hidden name
/// and renames it when every file is in, so the app never sees half a batch. The files are copies
/// without encryption, so they're protected while the phone is locked and the app deletes them
/// right after reading them (ImportInbox).
enum SharedInbox {
    static let appGroup = "group.mx.com.claudita.ultrascanner"
    /// The extension opens the app with this URL once the batch is ready.
    static let openURL = URL(string: "ultrascanner://import")!

    static var directory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("Inbox", isDirectory: true)
    }

    /// Ready batches, oldest first; inside each, the files in the order they were shared.
    static func readyBatches(in directory: URL) -> [URL] {
        let batches = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        return batches.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func files(in batch: URL) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: batch, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        return files.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// A new batch's final name: sorts by time, unique.
    static func batchName() -> String {
        "\(Int(Date.now.timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(8))"
    }
}
