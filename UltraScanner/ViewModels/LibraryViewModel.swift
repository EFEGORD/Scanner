import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var documents: [ScanDocument] = []
    @Published var folders: [ScanFolder] = []
    @Published var pageCounts: [String: Int] = [:]
    @Published var selectedFolderId: String?
    @Published var searchQuery: String = "" {
        didSet { runSearch() }
    }
    @Published var searchResults: [DocumentRepository.SearchHit] = []
    /// False only when the user has never saved a document — drives the empty state.
    @Published private(set) var hasAnyDocument = true

    private let repository = DocumentRepository.shared

    var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func load() {
        do {
            documents = try repository.allDocuments(inFolder: selectedFolderId)
            folders = try repository.allFolders()
            pageCounts = try repository.pageCounts()
            if selectedFolderId == nil {
                hasAnyDocument = !documents.isEmpty
            } else {
                hasAnyDocument = try !repository.allDocuments(inFolder: nil).isEmpty
            }
            if isSearching { runSearch() }
        } catch {
            // Local-only app: a read failure means the encrypted store couldn't be opened.
            print("No se pudo cargar la biblioteca: \(error)")
        }
    }

    func selectFolder(_ id: String?) {
        selectedFolderId = id
        load()
    }

    func folderName(for document: ScanDocument) -> String {
        folders.first { $0.id == document.folderId }?.name ?? "Sin carpeta"
    }

    func pageCountText(for document: ScanDocument) -> String {
        let count = pageCounts[document.id] ?? 0
        return count == 1 ? "1 página" : "\(count) páginas"
    }

    func createFolder(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        _ = try? repository.createFolder(name: trimmed)
        load()
    }

    func delete(_ document: ScanDocument) {
        try? repository.deleteDocument(id: document.id)
        load()
    }

    private func runSearch() {
        guard isSearching else {
            searchResults = []
            return
        }
        searchResults = (try? repository.search(searchQuery)) ?? []
    }
}
