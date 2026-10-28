import SwiftUI

/// Matches Home.dc.html / Vacia.dc.html: title with "Combinar" + Ajustes, a visible search
/// field (the star feature), folder chips, the document list, and the "Importar" / "Escanear"
/// buttons. Also opens files shared to the app from elsewhere (ImportInbox).
/// No bottom tab bar — everything lives on this one screen.
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showScanner = false
    @State private var showCombine = false
    @State private var showSettings = false
    @State private var showNewFolderPrompt = false
    @State private var newFolderName = ""
    @State private var path: [ScanDocument] = []
    @State private var showImporter = false
    @State private var importBatch: ImportBatch?
    @State private var isImporting = false
    @State private var importError: String?
    @ObservedObject private var inbox = ImportInbox.shared
    @ObservedObject private var appLock = AppLockManager.shared

    var body: some View {
        NavigationStack(path: $path) {
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
                    EmptyLibraryView(onScan: { showScanner = true }, onImport: { showImporter = true })
                }
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.hasAnyDocument && !viewModel.isSearching {
                    actionBar
                }
            }
            .overlay {
                if isImporting {
                    ProgressView("Abriendo…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ScanDocument.self) { document in
                DocumentViewerView(document: document, onChange: { viewModel.load() })
            }
            .onAppear { viewModel.load() }
            #if DEBUG
            .task { openDemoScreen() }
            #endif
            .fullScreenCover(isPresented: $showScanner, onDismiss: { viewModel.load() }) {
                ScanCaptureView(onDone: {})
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: DocumentImporter.contentTypes,
                          allowsMultipleSelection: true) { result in
                if case .success(let urls) = result, !urls.isEmpty { startImport(urls, source: "files") }
            }
            .fullScreenCover(item: $importBatch, onDismiss: { viewModel.load() }) { batch in
                ImportFlowView(batch: batch)
            }
            .alert("No se pudo importar", isPresented: Binding(get: { importError != nil },
                                                             set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
            // Shared from another app: only once unlocked, so it can't open past Face ID.
            .onAppear(perform: importShared)
            .onChange(of: inbox.pending) { importShared() }
            .onChange(of: appLock.isLocked) { importShared() }
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
                chip(title: String(localized: "Todos"), isSelected: viewModel.selectedFolderId == nil) {
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
    }

    /// Matches Home.dc.html: Importar and Escanear side by side in a bar under the list, so they
    /// never cover a document; Escanear is the main one (1 : 1.6).
    private var actionBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 12) {
                importButton
                    .frame(width: (geometry.size.width - 12) / 2.6)
                scanButton
            }
        }
        .frame(height: 54)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider() }
    }

    private var scanButton: some View {
        Button { showScanner = true } label: {
            Label("Escanear", systemImage: "doc.viewfinder")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraGradient, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.accentColor.opacity(0.3), radius: 6, y: 3)
        }
    }

    private var importButton: some View {
        Button { showImporter = true } label: {
            Label("Importar", systemImage: "square.and.arrow.down")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1.5))
        }
        .disabled(isImporting)
    }

    // MARK: - Import

    private func importShared() {
        guard !appLock.isLocked, importBatch == nil, !isImporting, !inbox.pending.isEmpty else { return }
        startImport(inbox.take(), source: "shared")
    }

    /// PDFs and images become pages for the same review → edit / sign → save flow as a scan.
    private func startImport(_ urls: [URL], source: String) {
        isImporting = true
        Task {
            defer {
                isImporting = false
                ImportInbox.discard(urls)
            }
            do {
                let imported = try await DocumentImporter.pages(from: urls)
                let session = ScanSessionViewModel()
                session.addCapturedPages(imported.pages)
                importBatch = ImportBatch(session: session, truncated: imported.truncated)
                AppAnalytics.log(.documentImported, ["pages": imported.pages.count, "source": source])
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    #if DEBUG
    private func openDemoScreen() {
        guard DemoMode.isActive else { return }
        switch DemoMode.screen {
        case "search": viewModel.searchQuery = DemoMode.searchQuery
        case "viewer": if let lease = DemoMode.document(titled: DemoMode.leaseTitle) { path = [lease] }
        case "combine": showCombine = true
        default: break
        }
    }
    #endif
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
