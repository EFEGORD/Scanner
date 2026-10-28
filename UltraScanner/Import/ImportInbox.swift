import Foundation

/// Photos and PDFs shared to UltraScanner from another app ("Compartir" › UltraScanner in Fotos,
/// WhatsApp, Mail, Archivos…). The share extension copies them, unencrypted, into the App Group
/// inbox (SharedInbox) and opens the app; the Biblioteca imports everything that's waiting once
/// the app is unlocked (never past the Face ID lock), and the copies are deleted right after being
/// read.
@MainActor
final class ImportInbox: ObservableObject {
    static let shared = ImportInbox()

    @Published private(set) var hasPending = false

    private init() {}

    /// Called when the extension opens the app, and whenever the app comes back (if iOS didn't let
    /// the extension open it, the user opens it themself).
    func refresh() {
        hasPending = SharedInbox.directory.map { !SharedInbox.readyBatches(in: $0).isEmpty } ?? false
    }

    /// Every shared file waiting, in the order it was shared.
    func take() -> [URL] {
        hasPending = false
        guard let directory = SharedInbox.directory else { return [] }
        return Self.claim(in: directory)
    }

    /// Moves each ready batch out of sight so it's never imported twice, and lists its files.
    nonisolated static func claim(in inbox: URL) -> [URL] {
        var files: [URL] = []
        for batch in SharedInbox.readyBatches(in: inbox) {
            let claimed = inbox.appendingPathComponent(".importing-\(batch.lastPathComponent)", isDirectory: true)
            guard (try? FileManager.default.moveItem(at: batch, to: claimed)) != nil else { continue }
            files += SharedInbox.files(in: claimed)
        }
        return files
    }

    /// Deletes the shared copies (and their batch folder). Files picked in Archivos are the user's
    /// own and stay.
    nonisolated static func discard(_ urls: [URL], inbox: URL? = SharedInbox.directory) {
        guard let inbox else { return }
        let root = inbox.standardizedFileURL.path + "/"
        var batches = Set<URL>()
        for url in urls where url.standardizedFileURL.path.hasPrefix(root) {
            try? FileManager.default.removeItem(at: url)
            batches.insert(url.deletingLastPathComponent())
        }
        for batch in batches where batch.standardizedFileURL.path.hasPrefix(root)
            && ((try? FileManager.default.contentsOfDirectory(atPath: batch.path)) ?? []).isEmpty {
            try? FileManager.default.removeItem(at: batch)
        }
    }

    /// Copies left behind: half-written or half-imported ones (older than ten minutes, so a share
    /// in progress isn't touched) and shares never opened in a day.
    nonisolated static func discardLeftovers(inbox: URL? = SharedInbox.directory, now: Date = .now) {
        guard let inbox,
              let batches = try? FileManager.default.contentsOfDirectory(
                at: inbox, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for batch in batches {
            let modified = (try? batch.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            let age = now.timeIntervalSince(modified ?? .distantPast)
            let hidden = batch.lastPathComponent.hasPrefix(".")
            if age > (hidden ? 10 * 60 : 24 * 60 * 60) {
                try? FileManager.default.removeItem(at: batch)
            }
        }
    }
}
