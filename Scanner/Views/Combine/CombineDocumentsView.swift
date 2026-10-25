import SwiftUI

/// Matches Combinar.dc.html: buscar (por contenido OCR), ver lo que ya se agregó al
/// nuevo documento, añadir documentos completos o páginas sueltas, o escanear más.
/// First-pass stub wired to the real search; armar/guardar el combinado llega en el
/// siguiente pase (usa DocumentRepository.mergePages).
struct CombineDocumentsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [DocumentRepository.SearchHit] = []

    private let repository = DocumentRepository.shared

    var body: some View {
        NavigationStack {
            VStack {
                TextField("Buscar por contenido: \"INE\", \"comprobante\"…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: query) { _, _ in runSearch() }

                List(results, id: \.page.id) { hit in
                    VStack(alignment: .leading) {
                        Text(hit.document.title).font(.subheadline.bold())
                        Text(hit.snippet).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Combinar documentos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private func runSearch() {
        results = (try? repository.search(query)) ?? []
    }
}
