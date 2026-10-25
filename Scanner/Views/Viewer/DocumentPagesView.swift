import SwiftUI

/// Pages of an already-saved document, with "Dividir aquí" to move every following page
/// into a new document (DocumentRepository.splitDocument).
struct DocumentPagesView: View {
    let document: ScanDocument
    let onChange: () -> Void

    @State private var pages: [ScanPage] = []
    @State private var splitAfter: ScanPage?

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            Text("Toca \"Dividir aquí\" para pasar las páginas siguientes a un documento nuevo.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    VStack(spacing: 8) {
                        SecureImageView(relativePath: page.thumbPath)
                            .aspectRatio(3.0 / 4.0, contentMode: .fit)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .bottomLeading) {
                                Text("\(index + 1)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor, in: Capsule())
                                    .foregroundStyle(.white)
                                    .padding(8)
                            }
                        if index < pages.count - 1 {
                            Button { splitAfter = page } label: {
                                Label("Dividir aquí", systemImage: "scissors")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Páginas")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .confirmationDialog(
            "¿Dividir el documento?",
            isPresented: Binding(get: { splitAfter != nil }, set: { if !$0 { splitAfter = nil } }),
            titleVisibility: .visible,
            presenting: splitAfter
        ) { page in
            Button("Dividir después de esta página") { split(after: page) }
        } message: { _ in
            Text("Las páginas siguientes pasan a un documento nuevo en la misma carpeta.")
        }
    }

    private func load() {
        pages = (try? DocumentRepository.shared.pages(of: document.id)) ?? []
    }

    private func split(after page: ScanPage) {
        _ = try? DocumentRepository.shared.splitDocument(
            document.id, afterPosition: page.position, newTitle: "\(document.title) (parte 2)")
        load()
        onChange()
    }
}
