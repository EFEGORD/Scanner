import SwiftUI

/// Matches Exportar.dc.html ("Guardar documento"): the ONE place a new scan gets saved.
/// Name (suggested from the first OCR line), folder, then "Guardar" → render edits + OCR +
/// encryption + database, then the interstitial ad, then back to the Biblioteca.
struct SaveDocumentView: View {
    @ObservedObject var session: ScanSessionViewModel
    let onSaved: () -> Void

    @State private var title = ""
    @State private var selectedFolderId: String?
    @State private var cover: UIImage?
    @State private var errorMessage: String?

    private var pageCountText: String {
        let count = session.pages.count
        return count == 1 ? "1 página escaneada" : "\(count) páginas escaneadas"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 14) {
                    if let cover {
                        Image(uiImage: cover)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Text(pageCountText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                DocumentDetailsForm(title: $title, selectedFolderId: $selectedFolderId,
                                    titleHint: "Sugerido a partir del texto del documento.")

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
    }

    private func prepare() async {
        guard let first = session.pages.first else { return }
        if cover == nil {
            cover = await Task.detached(priority: .userInitiated) { first.preview() }.value
        }
        guard title.isEmpty else { return }

        let placeholder = "Documento \(Date().formatted(date: .numeric, time: .omitted))"
        title = placeholder
        guard let text = try? await TextRecognizer.recognizeText(in: first.original),
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
