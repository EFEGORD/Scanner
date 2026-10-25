import SwiftUI

/// Matches Exportar.dc.html ("Guardar documento"): the ONE place a new scan gets saved.
/// Name (suggested from the first OCR line), folder, then "Guardar" → OCR + encryption +
/// database, then the interstitial ad, then back to the Biblioteca.
struct SaveDocumentView: View {
    @ObservedObject var session: ScanSessionViewModel
    let onSaved: () -> Void

    @State private var title = ""
    @State private var folders: [ScanFolder] = []
    @State private var selectedFolderId: String?
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var errorMessage: String?

    private var pageCountText: String {
        let count = session.capturedImages.count
        return count == 1 ? "1 página escaneada" : "\(count) páginas escaneadas"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 14) {
                    if let first = session.capturedImages.first {
                        Image(uiImage: first)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Text(pageCountText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nombre")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Nombre del documento", text: $title)
                        .padding(14)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    Text("Sugerido a partir del texto del documento.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Carpeta")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            folderChip("Sin carpeta", id: nil)
                            ForEach(folders) { folder in
                                folderChip(folder.name, id: folder.id)
                            }
                            Button { showNewFolder = true } label: {
                                Text("+ Carpeta")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .overlay(
                                        Capsule().strokeBorder(Color(.systemGray3), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                    )
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Label("Se guarda cifrado, solo en este teléfono.", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.green)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

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
                if session.isProcessing {
                    ProgressView("Leyendo el texto y cifrando…")
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
        .task { await prepare() }
        .alert("Nueva carpeta", isPresented: $showNewFolder) {
            TextField("Nombre", text: $newFolderName)
            Button("Cancelar", role: .cancel) { newFolderName = "" }
            Button("Crear") { createFolder() }
        }
    }

    private func folderChip(_ name: String, id: String?) -> some View {
        let isSelected = selectedFolderId == id
        return Button { selectedFolderId = id } label: {
            Text(name)
                .font(.subheadline.weight(isSelected ? .bold : .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
    }

    private func prepare() async {
        folders = (try? DocumentRepository.shared.allFolders()) ?? []
        guard title.isEmpty else { return }

        let placeholder = "Documento \(Date().formatted(date: .numeric, time: .omitted))"
        title = placeholder
        guard let first = session.capturedImages.first,
              let text = try? await TextRecognizer.recognizeText(in: first),
              let suggestion = Self.suggestedTitle(from: text),
              title == placeholder // the user hasn't started typing their own name
        else { return }
        title = suggestion
    }

    static func suggestedTitle(from text: String) -> String? {
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.count >= 3 }
        guard let firstLine else { return nil }
        return String(firstLine.prefix(40))
    }

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        newFolderName = ""
        guard !name.isEmpty, let folder = try? DocumentRepository.shared.createFolder(name: name) else { return }
        folders = (try? DocumentRepository.shared.allFolders()) ?? []
        selectedFolderId = folder.id
    }

    private func save() async {
        errorMessage = nil
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        do {
            _ = try await session.saveAsDocument(
                title: trimmed.isEmpty ? "Documento sin título" : trimmed,
                folderId: selectedFolderId)
            AdManager.shared.showIfReady(from: UIApplication.topViewController()) {
                onSaved()
            }
        } catch {
            errorMessage = "No se pudo guardar el documento."
        }
    }
}
