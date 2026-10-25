import SwiftUI

/// Matches Home.dc.html / Vacia.dc.html: title with "Combinar" + Ajustes, a visible search
/// field (the star feature), folder chips, the document list, and an "Escanear" button.
/// No bottom tab bar — everything lives on this one screen.
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showScanner = false
    @State private var showCombine = false
    @State private var showSettings = false
    @State private var showNewFolderPrompt = false
    @State private var newFolderName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if viewModel.hasAnyDocument {
                    searchField
                    if viewModel.isSearching {
                        searchResults
                    } else {
                        folderChips
                        documentList
                    }
                } else {
                    EmptyLibraryView { showScanner = true }
                }
            }
            .background(Color(.systemGroupedBackground))
            .overlay(alignment: .bottomTrailing) {
                if viewModel.hasAnyDocument && !viewModel.isSearching {
                    scanButton
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ScanDocument.self) { document in
                DocumentViewerView(document: document, onChange: { viewModel.load() })
            }
            .onAppear { viewModel.load() }
            .fullScreenCover(isPresented: $showScanner, onDismiss: { viewModel.load() }) {
                ScanCaptureView(onDone: {})
            }
            .sheet(isPresented: $showCombine, onDismiss: { viewModel.load() }) {
                CombineDocumentsView()
            }
            .sheet(isPresented: $showSettings, onDismiss: { viewModel.load() }) {
                SettingsView()
            }
            .alert("Nueva carpeta", isPresented: $showNewFolderPrompt) {
                TextField("Nombre", text: $newFolderName)
                Button("Cancelar", role: .cancel) { newFolderName = "" }
                Button("Crear") {
                    viewModel.createFolder(name: newFolderName)
                    newFolderName = ""
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text("Mis documentos")
                .font(.largeTitle.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            if viewModel.hasAnyDocument {
                Button { showCombine = true } label: {
                    Label("Combinar", systemImage: "rectangle.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .frame(width: 38, height: 38)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Ajustes")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.primary)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Buscar texto dentro de tus documentos", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if viewModel.isSearching {
                Button { viewModel.searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Borrar búsqueda")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 14)
    }

    private var searchResults: some View {
        List {
            if viewModel.searchResults.isEmpty {
                Text("Sin resultados para \"\(viewModel.searchQuery)\".")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(viewModel.searchResults, id: \.page.id) { hit in
                NavigationLink(value: hit.document) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hit.document.title)
                            .font(.subheadline.weight(.bold))
                        if let label = hit.page.documentLabel {
                            Label(label, systemImage: "person.text.rectangle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        Text("Página \(hit.page.position + 1) · \(hit.snippet)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Folders

    private var folderChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "Todos", isSelected: viewModel.selectedFolderId == nil) {
                    viewModel.selectFolder(nil)
                }
                ForEach(viewModel.folders) { folder in
                    chip(title: folder.name, isSelected: viewModel.selectedFolderId == folder.id) {
                        viewModel.selectFolder(folder.id)
                    }
                }
                Button { showNewFolderPrompt = true } label: {
                    Text("+ Carpeta")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(
                            Capsule().strokeBorder(Color(.systemGray3), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                        )
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Nueva carpeta")
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 14)
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .bold : .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemBackground), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
    }

    // MARK: - Documents

    private var documentList: some View {
        List {
            if viewModel.documents.isEmpty {
                Text("No hay documentos en esta carpeta.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            ForEach(viewModel.documents) { document in
                NavigationLink(value: document) {
                    DocumentRowView(
                        document: document,
                        subtitle: "\(document.updatedAt.formatted(date: .abbreviated, time: .omitted)) · \(viewModel.pageCountText(for: document)) · \(viewModel.folderName(for: document))"
                    )
                }
                .swipeActions {
                    Button(role: .destructive) { viewModel.delete(document) } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
    }

    private var scanButton: some View {
        Button { showScanner = true } label: {
            Label("Escanear", systemImage: "doc.viewfinder")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .frame(height: 58)
                .background(Color.accentColor, in: Capsule())
                .shadow(color: Color.accentColor.opacity(0.35), radius: 10, y: 6)
        }
        .padding(20)
    }
}

private struct DocumentRowView: View {
    let document: ScanDocument
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            SecureImageView(relativePath: document.thumbnailPath)
                .frame(width: 48, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(document.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
