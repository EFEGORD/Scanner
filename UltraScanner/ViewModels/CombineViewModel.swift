import Foundation
import UIKit

/// "Combinar documentos": build a NEW document out of whole documents, single pages found by
/// search, and freshly scanned pages. The source documents are never modified — their
/// encrypted page files are copied.
@MainActor
final class CombineViewModel: ObservableObject {
    struct TrayItem: Identifiable {
        enum Source {
            case page(ScanPage)
            case scanned(UIImage)
        }

        let id = UUID()
        let source: Source

        var pageId: String? {
            if case .page(let page) = source { return page.id }
            return nil
        }
    }

    struct Candidate: Identifiable {
        let document: ScanDocument
        let pages: [ScanPage]
        let matchedPageIds: Set<String>
        var id: String { document.id }
    }

    @Published var query = "" {
        didSet { refreshResults() }
    }
    @Published private(set) var tray: [TrayItem] = []
    @Published private(set) var results: [Candidate] = []
    @Published private(set) var isSaving = false

    private let repository = DocumentRepository.shared

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var trayTitle: String {
        tray.count == 1
            ? String(localized: "Nuevo documento · 1 hoja")
            : String(localized: "Nuevo documento · \(tray.count) hojas")
    }

    /// With no search, every document is listed so you can browse; with a search, only the
    /// documents whose text matches, with the matching pages highlighted.
    func refreshResults() {
        do {
            let documents: [ScanDocument]
            var matched = Set<String>()
            if isSearching {
                var seen = Set<String>()
                documents = try repository.search(query).compactMap { hit in
                    matched.insert(hit.page.id)
                    return seen.insert(hit.document.id).inserted ? hit.document : nil
                }
            } else {
                documents = try repository.allDocuments()
            }
            results = try documents.map { document in
                Candidate(document: document, pages: try repository.pages(of: document.id), matchedPageIds: matched)
            }
        } catch {
            results = []
        }
    }

    func preload(_ document: ScanDocument) {
        guard let candidate = try? Candidate(document: document, pages: repository.pages(of: document.id),
                                             matchedPageIds: []) else { return }
        addAll(candidate)
    }

    func isInTray(_ page: ScanPage) -> Bool {
        tray.contains { $0.pageId == page.id }
    }

    func isFullyAdded(_ candidate: Candidate) -> Bool {
        !candidate.pages.isEmpty && candidate.pages.allSatisfy(isInTray)
    }

    func toggle(_ page: ScanPage) {
        if let index = tray.firstIndex(where: { $0.pageId == page.id }) {
            tray.remove(at: index)
        } else {
            tray.append(TrayItem(source: .page(page)))
        }
    }

    func addAll(_ candidate: Candidate) {
        for page in candidate.pages where !isInTray(page) {
            tray.append(TrayItem(source: .page(page)))
        }
    }

    func addScanned(_ images: [UIImage]) {
        tray.append(contentsOf: images.map { TrayItem(source: .scanned($0)) })
    }

    func remove(_ item: TrayItem) {
        tray.removeAll { $0.id == item.id }
    }

    func move(_ item: TrayItem, by offset: Int) {
        guard let index = tray.firstIndex(where: { $0.id == item.id }),
              tray.indices.contains(index + offset) else { return }
        tray.swapAt(index, index + offset)
    }

    func save(title: String, folderId: String?) async throws -> ScanDocument {
        isSaving = true
        defer { isSaving = false }

        var pages: [ScanPage] = []
        for (position, item) in tray.enumerated() {
            switch item.source {
            case .page(let page):
                pages.append(try PageFactory.duplicate(page, position: position))
            case .scanned(let image):
                pages.append(try await PageFactory.makePage(from: image, position: position))
            }
        }
        let document = try repository.createDocument(title: title, folderId: folderId, pages: pages)
        tray = []
        return document
    }
}
