import SwiftUI

/// Matches Combinar.dc.html: search (by OCR text) or browse, add whole documents or single
/// pages to the tray, scan extra pages, reorder, then save as a new document.
struct CombineDocumentsView: View {
    var initialDocument: ScanDocument? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CombineViewModel()
    @State private var showScanner = false
    @State private var goToSave = false
    @State private var didPreload = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                tray
                Divider()
                resultsList
                bottomBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Combinar documentos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onAppear {
                viewModel.refreshResults()
                if !didPreload, let initialDocument {
                    viewModel.preload(initialDocument)
                    didPreload = true
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScannerView(
                    onFinish: { viewModel.addScanned($0); showScanner = false },
                    onCancel: { showScanner = false }
                )
                .ignoresSafeArea()
            }
            .navigationDestination(isPresented: $goToSave) {
                CombineSaveView(viewModel: viewModel, onSaved: { dismiss() })
            }
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Buscar por contenido: \"INE\", \"comprobante\"…", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if viewModel.isSearching {
                Button { viewModel.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .accessibilityLabel("Borrar búsqueda")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    // MARK: - Tray

    private var tray: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.trayTitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if viewModel.tray.isEmpty {
                Text("Toca + en las páginas de abajo, o \"Añadir todo\", para armar el documento.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .frame(height: 76, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(viewModel.tray.enumerated()), id: \.element.id) { index, item in
                            trayCell(item, index: index)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .frame(height: 84)
            }
        }
        .padding(.bottom, 12)
    }

    private func trayCell(_ item: CombineViewModel.TrayItem, index: Int) -> some View {
        Group {
            switch item.source {
            case .page(let page):
                SecureImageView(relativePath: page.thumbPath)
            case .scanned(let image):
                Image(uiImage: image).resizable().scaledToFill()
            }
        }
        .frame(width: 52, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentColor, lineWidth: 2))
        .overlay(alignment: .bottomLeading) {
            Text("\(index + 1)")
                .font(.caption2.bold())
                .padding(.horizontal, 5)
                .background(Color.accentColor, in: Capsule())
                .foregroundStyle(.white)
                .padding(4)
        }
        .overlay(alignment: .topTrailing) {
            Button { viewModel.remove(item) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.white, Color.black.opacity(0.6))
            }
            .offset(x: 6, y: -6)
            .accessibilityLabel("Quitar hoja \(index + 1)")
        }
        .contextMenu {
            Button { viewModel.move(item, by: -1) } label: { Label("Mover antes", systemImage: "arrow.left") }
                .disabled(index == 0)
            Button { viewModel.move(item, by: 1) } label: { Label("Mover después", systemImage: "arrow.right") }
                .disabled(index == viewModel.tray.count - 1)
            Button(role: .destructive) { viewModel.remove(item) } label: { Label("Quitar", systemImage: "trash") }
        }
    }

    // MARK: - Results

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if viewModel.results.isEmpty {
                    Group {
                        if viewModel.isSearching {
                            Text("Sin resultados para \"\(viewModel.query)\".")
                        } else {
                            Text("Aún no tienes documentos.")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 24)
                }
                ForEach(viewModel.results) { candidate in
                    candidateCard(candidate)
                }
            }
            .padding()
        }
    }

    private func candidateCard(_ candidate: CombineViewModel.Candidate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.document.title)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Text(subtitle(for: candidate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.isFullyAdded(candidate) {
                    Label("Añadido", systemImage: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.green)
                } else {
                    Button { viewModel.addAll(candidate) } label: {
                        Text("+ Añadir todo")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .overlay(Capsule().strokeBorder(Color.accentColor, lineWidth: 1.5))
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(candidate.pages.enumerated()), id: \.element.id) { index, page in
                        pageToggle(page, index: index, matched: candidate.matchedPageIds.contains(page.id))
                    }
                }
                .padding(.top, 6)
                .padding(.trailing, 6)
            }
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func subtitle(for candidate: CombineViewModel.Candidate) -> String {
        let count = candidate.pages.count == 1
            ? String(localized: "1 página")
            : String(localized: "\(candidate.pages.count) páginas")
        if candidate.matchedPageIds.isEmpty { return count }
        let hits = candidate.pages.filter { candidate.matchedPageIds.contains($0.id) }.count
        return hits == 1
            ? String(localized: "\(count) · coincide en 1 página")
            : String(localized: "\(count) · coincide en \(hits) páginas")
    }

    private func pageToggle(_ page: ScanPage, index: Int, matched: Bool) -> some View {
        let added = viewModel.isInTray(page)
        return Button { viewModel.toggle(page) } label: {
            SecureImageView(relativePath: page.thumbPath)
                .frame(width: 48, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(added ? Color.accentColor : (matched ? Color.orange : Color(.systemGray4)),
                                      lineWidth: added || matched ? 2 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: added ? "checkmark.circle.fill" : "plus.circle.fill")
                        .foregroundStyle(Color.white, added ? Color.accentColor : Color.gray)
                        .offset(x: 6, y: -6)
                }
        }
        .accessibilityLabel(added ? Text("Quitar página \(index + 1)") : Text("Añadir página \(index + 1)"))
    }

    // MARK: - Bottom

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button { showScanner = true } label: {
                Label("Escanear página", systemImage: "doc.viewfinder")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(.systemGray4)))
            }
            .foregroundStyle(Color.primary)

            Button("Guardar documento") { goToSave = true }
                .buttonStyle(.primaryFilled)
                .disabled(viewModel.tray.isEmpty)
        }
        .padding()
        .background(.bar)
    }
}

/// Name + folder for the combined document, then save → ad → close.
private struct CombineSaveView: View {
    @ObservedObject var viewModel: CombineViewModel
    let onSaved: () -> Void

    @State private var title = String(localized: "Documento combinado")
    @State private var selectedFolderId: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(viewModel.trayTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                DocumentDetailsForm(title: $title, selectedFolderId: $selectedFolderId,
                                    titleHint: String(localized: "Los documentos originales no se modifican."))
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if viewModel.isSaving {
                    ProgressView("Combinando y cifrando…")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Button("Guardar") { Task { await save() } }
                        .buttonStyle(.primaryFilled)
                        .padding()
                }
            }
            .background(.bar)
        }
        .navigationTitle("Guardar documento")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() async {
        errorMessage = nil
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        do {
            _ = try await viewModel.save(title: trimmed.isEmpty ? String(localized: "Documento combinado") : trimmed,
                                         folderId: selectedFolderId)
            onSaved()
        } catch {
            errorMessage = String(localized: "No se pudo guardar el documento combinado.")
        }
    }
}
