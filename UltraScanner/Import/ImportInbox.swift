import Foundation

/// Files shared to UltraScanner from another app ("Compartir" › UltraScanner in WhatsApp, Mail,
/// Files…). iOS copies each one, unencrypted, into Documents/Inbox and opens the app with its URL;
/// the Biblioteca imports it once the app is unlocked (never past the Face ID lock), and the copy
/// is deleted right after being read.
@MainActor
final class ImportInbox: ObservableObject {
    static let shared = ImportInbox()

    @Published private(set) var pending: [URL] = []

    private init() {}

    func receive(_ url: URL) {
        pending.append(url)
    }

    func take() -> [URL] {
        defer { pending = [] }
        return pending
    }

    /// Deletes the copies iOS made for us. Files picked in Files are the user's own and stay.
    nonisolated static func discard(_ urls: [URL]) {
        for url in urls where isInbox(url) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Copies left behind if the app closed before importing them (older than ten minutes, so a
    /// file that just opened the app isn't touched).
    nonisolated static func discardLeftovers() {
        guard let inbox = inboxURL,
              let files = try? FileManager.default.contentsOfDirectory(
                at: inbox, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let cutoff = Date.now.addingTimeInterval(-10 * 60)
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if (modified ?? .distantPast) < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private nonisolated static var inboxURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Inbox", isDirectory: true)
    }

    private nonisolated static func isInbox(_ url: URL) -> Bool {
        guard let inbox = inboxURL?.standardizedFileURL.path else { return false }
        return url.standardizedFileURL.path.hasPrefix(inbox + "/")
    }
}
