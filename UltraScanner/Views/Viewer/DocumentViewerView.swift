import SwiftUI

/// Matches Visor.dc.html: swipe through the pages, thumbnails strip, and the four actions
/// (Compartir, Editar y firmar, Páginas, Combinar). Renombrar / Mover / Eliminar live in
/// the "⋯" menu.
struct DocumentViewerView: View {
    let onChange: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var document: ScanDocument
    @State private var pages: [ScanPage] = []
    @State private var folders: [ScanFolder] = []
    @State private var currentPage = 0
    @State private var showShare = false
    @State private var showCombine = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var confirmDelete = false

    private let repository = DocumentRepository.shared

    init(document: ScanDocument, onChange: @escaping () -> Void) {
        _document = State(initialValue: document)
        self.onChange = onChange
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    SecureImageView(relativePath: page.imagePath, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if pages.count > 1 {
                thumbnails
            }

            actionBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(document.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) { moreMenu }
        }
        .onAppear(perform: reload)
        .sheet(isPresented: $showShare) {
            ShareDocumentView(document: document)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showCombine, onDismiss: {
            reload()
            onChange()
        }) {
            CombineDocumentsView(initialDocument: document)
        }
        .alert("Renombrar", isPresented: $showRename) {
            TextField("Nombre", text: $renameText)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") { rename() }
        }
        .confirmationDialog("¿Eliminar este documento?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { delete() }
        } message: {
            Text("Se borra de este teléfono y no se puede recuperar.")
        }
    }

    private var subtitle: String {
        let count = pages.count == 1 ? "1 página" : "\(pages.count) páginas"
        let folder = folders.first { $0.id == document.folderId }?.name ?? "Sin carpeta"
        return "\(count) · \(folder)"
    }

    private var thumbnails: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    Button { withAnimation { currentPage = index } } label: {
                        SecureImageView(relativePath: page.thumbPath)
                            .frame(width: 40, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(index == currentPage ? Color.accentColor : Color(.systemGray4),
                                                  lineWidth: index == currentPage ? 2 : 1)
                            )
                    }
                    .accessibilityLabel("Página \(index + 1)")
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 16)
    }

    private var actionBar: some View {
        HStack(alignment: .top) {
            Button { showShare = true } label: {
                actionLabel("Compartir", systemImage: "square.and.arrow.up", highlighted: true)
            }
            NavigationLink {
                DocumentEditView(document: document, onSaved: {
                    reload()
                    onChange()
                })
            } label: {
                actionLabel("Editar y firmar", systemImage: "pencil.tip.crop.circle")
            }
            NavigationLink {
                DocumentPagesView(document: document, onChange: {
                    reload()
                    onChange()
                })
            } label: {
                actionLabel("Páginas", systemImage: "scissors")
            }
            Button { showCombine = true } label: {
                actionLabel("Combinar", systemImage: "rectangle.on.rectangle")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) { Divider() }
    }

    private func actionLabel(_ title: String, systemImage: String, highlighted: Bool = false) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
            Text(title)
                .font(.caption.weight(highlighted ? .bold : .semibold))
        }
        .foregroundStyle(highlighted ? Color.accentColor : Color.primary)
        .frame(maxWidth: .infinity)
    }

    private var moreMenu: some View {
        Menu {
            Button {
                renameText = document.title
                showRename = true
            } label: {
                Label("Renombrar", systemImage: "pencil")
            }
            Menu {
                Button("Sin carpeta") { move(to: nil) }
                ForEach(folders) { folder in
                    Button(folder.name) { move(to: folder.id) }
                }
            } label: {
                Label("Mover a carpeta", systemImage: "folder")
            }
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Eliminar", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Más opciones")
    }

    // MARK: - Actions

    private func reload() {
        if let fresh = try? repository.document(id: document.id) {
            document = fresh
        }
        pages = (try? repository.pages(of: document.id)) ?? []
        folders = (try? repository.allFolders()) ?? []
        if currentPage >= pages.count { currentPage = max(pages.count - 1, 0) }
    }

    private func rename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        try? repository.renameDocument(id: document.id, to: trimmed)
        reload()
        onChange()
    }

    private func move(to folderId: String?) {
        try? repository.moveDocument(id: document.id, toFolder: folderId)
        reload()
        onChange()
    }

    private func delete() {
        try? repository.deleteDocument(id: document.id)
        onChange()
        dismiss()
    }
}
