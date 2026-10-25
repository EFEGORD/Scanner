import SwiftUI

/// Editing an EXISTING, already-saved document (opened from the Biblioteca).
/// First-pass stub: shows the pages and lets the user rename the document.
/// Filters/rotate/crop/firma land in a follow-up pass — see SETUP.md.
struct DocumentEditView: View {
    let document: ScanDocument
    @State private var title: String

    init(document: ScanDocument) {
        self.document = document
        _title = State(initialValue: document.title)
    }

    var body: some View {
        VStack(spacing: 16) {
            TextField("Nombre del documento", text: $title)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            ContentUnavailableView(
                "Vista de páginas en construcción",
                systemImage: "doc.text.image",
                description: Text("Aquí van las páginas de \"\(document.title)\" con filtros, rotar, recortar y firmar.")
            )
        }
        .padding(.top)
        .navigationTitle("Editar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Editing pages that were just captured, BEFORE the document exists in the database.
/// This is the step that calls ScanSessionViewModel.saveAsDocument(...).
struct NewDocumentEditView: View {
    @ObservedObject var session: ScanSessionViewModel
    let onSaved: () -> Void

    @State private var title: String = "Documento sin título"
    @State private var goToExport = false
    @State private var savedDocument: ScanDocument?

    var body: some View {
        VStack(spacing: 16) {
            if let first = session.capturedImages.first {
                Image(uiImage: first)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 10)
            }

            Text("Filtros, rotar, recortar y firma se agregan en el siguiente pase de UI.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            if session.isProcessing {
                ProgressView("Procesando y cifrando…")
            } else {
                Button("Guardar") { Task { await save() } }
                    .buttonStyle(.primaryFilled)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .navigationTitle("Página \(1) de \(session.capturedImages.count)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToExport) {
            if let savedDocument {
                ExportView(document: savedDocument, onFinished: onSaved)
            }
        }
    }

    private func save() async {
        do {
            let document = try await session.saveAsDocument(title: title, folderId: nil)
            savedDocument = document
            goToExport = true
        } catch {
            print("No se pudo guardar el documento: \(error)")
        }
    }
}
