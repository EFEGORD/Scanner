import SwiftUI

/// Editing pages that were just captured, BEFORE the document exists. "Siguiente" goes to
/// Guardar, where the edits are rendered, read and encrypted.
struct NewDocumentEditView: View {
    @ObservedObject var session: ScanSessionViewModel
    let onSaved: () -> Void

    @State private var goToSave = false

    var body: some View {
        PageEditorView(pages: $session.pages, primaryTitle: "Siguiente") {
            goToSave = true
        }
        .navigationDestination(isPresented: $goToSave) {
            SaveDocumentView(session: session, onSaved: onSaved)
        }
    }
}

/// Editing an already-saved document (Visor → "Editar y firmar"). Only the pages that were
/// actually changed are re-encrypted; their old files are deleted.
struct DocumentEditView: View {
    let document: ScanDocument
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pages: [PageEditState] = []
    @State private var sourcePages: [ScanPage] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Abriendo…")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.ignoresSafeArea())
            } else {
                PageEditorView(pages: $pages, primaryTitle: "Guardar cambios", isBusy: isSaving) {
                    Task { await save() }
                }
            }
        }
        .task { await load() }
        .alert("No se pudieron guardar los cambios", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func load() async {
        guard isLoading else { return }
        sourcePages = (try? DocumentRepository.shared.pages(of: document.id)) ?? []
        var loaded: [PageEditState] = []
        var kept: [ScanPage] = []
        for page in sourcePages {
            // The stored image already has its earlier edits baked in: it is the new "original".
            if let image = await PageFactory.loadImage(of: page) {
                loaded.append(PageEditState(original: image))
                kept.append(page)
            }
        }
        sourcePages = kept
        pages = loaded
        isLoading = false
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            for (state, source) in zip(pages, sourcePages) where state.hasEdits {
                let final = await Task.detached(priority: .userInitiated) { state.rendered() }.value
                let fresh = try await PageFactory.makePage(from: final, position: source.position)
                try DocumentRepository.shared.replacePageImage(
                    source, with: fresh,
                    filter: state.filter, rotation: (source.rotation + (state.quarterTurns % 4) * 90) % 360)
            }
            let edited = pages.filter(\.hasEdits)
            if !edited.isEmpty {
                AppAnalytics.log(.documentEdited, ["pages": edited.count,
                                                   "signed": edited.contains { !$0.signatures.isEmpty } ? 1 : 0])
            }
            onSaved()
            dismiss()
        } catch {
            errorMessage = String(localized: "Intenta de nuevo.")
        }
    }
}
