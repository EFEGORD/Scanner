import Foundation

/// Photos and PDFs shared to UltraScanner from another app ("Compartir" › UltraScanner in Fotos,
/// WhatsApp, Mail, Archivos…). The share extension leaves them in the shared Keychain inbox
/// (SharedInbox) and opens the app; the Biblioteca imports everything that's waiting once the app
/// is unlocked (never past the Face ID lock), and the inbox is emptied as it's read.
@MainActor
final class ImportInbox: ObservableObject {
    static let shared = ImportInbox()

    @Published private(set) var hasPending = false

    private init() {}

    /// Called when the extension opens the app, and whenever the app comes back (if iOS didn't let
    /// the extension open it, the user opens it themself).
    func refresh() {
        hasPending = !SharedInbox.readyBatches(in: SharedInbox.entries().map(\.account)).isEmpty
    }

    /// Clears the flag before the (slow) read, so the same share isn't imported twice.
    func markTaken() {
        hasPending = false
    }

    /// Every shared file waiting, in the order it was shared; each one is deleted from the inbox as
    /// it's read. Off the main thread: a share can be tens of megabytes.
    nonisolated static func takeAll() -> [Data] {
        var files: [Data] = []
        for batch in SharedInbox.readyBatches(in: SharedInbox.entries().map(\.account)) {
            for file in batch.files {
                if let data = SharedInbox.data(batch: batch.name, file: file) { files.append(data) }
                SharedInbox.remove(account: "\(batch.name)/\(file)")
            }
            SharedInbox.remove(account: batch.name)
        }
        return files
    }

    /// Items left behind: half-written shares (older than ten minutes, so a share in progress isn't
    /// touched) and shares never opened in a day.
    nonisolated static func discardLeftovers(now: Date = .now) {
        let entries = SharedInbox.entries()
        let ready = Set(SharedInbox.readyBatches(in: entries.map(\.account)).map(\.name))
        for entry in entries {
            let batch = String(entry.account.split(separator: "/").first ?? "")
            let age = now.timeIntervalSince(entry.created)
            if age > (ready.contains(batch) ? 24 * 60 * 60 : 10 * 60) {
                SharedInbox.remove(account: entry.account)
            }
        }
    }
}
