import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var documents: [ScanDocument] = []
    @Published var folders: [ScanFolder] = []
    @Published var selectedFolderId: String?
    @Published var searchQuery: String = ""
    @Published var searchResults: [DocumentRepository.SearchHit] = []

    private let repository = DocumentRepository.shared

    func load() {
        do {
            documents = try repository.allDocuments(inFolder: selectedFolderId)
            folders = try repository.allFolders()
        } catch {
            // Local-only app: a read failure here means the encrypted store couldn't be
            // opened. Surface it instead of silently showing an empty library.
            print("No se pudo cargar la biblioteca: \(error)")
        }
    }

    func selectFolder(_ id: String?) {
        selectedFolderId = id
        load()
    }

    func runSearch() {
        guard !searchQuery.isEmpty else { searchResults = []; return }
        do {
            searchResults = try repository.search(searchQuery)
        } catch {
            searchResults = []
        }
    }

    func createFolder(name: String) {
        _ = try? repository.createFolder(name: name)
        load()
    }

    func delete(_ document: ScanDocument) {
        try? repository.deleteDocument(id: document.id)
        load()
    }
}
