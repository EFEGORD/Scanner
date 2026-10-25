import SwiftUI

/// Matches Revision.dc.html: the captured pages before editing. Long-press a page to move
/// it or delete it; "Agregar" scans more pages into the same batch.
struct PageReviewView: View {
    @ObservedObject var session: ScanSessionViewModel
    let onDone: () -> Void

    @State private var showScanner = false
    @State private var goToEdit = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            Text("Mantén presionada una página para moverla o eliminarla.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(session.pages.enumerated()), id: \.element.id) { index, page in
                        pageCell(page, index: index)
                    }

                    Button { showScanner = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Agregar").font(.caption.bold())
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(3.0 / 4.0, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color(.systemGray3), style: StrokeStyle(lineWidth: 2, dash: [6]))
                        )
                    }
                    .accessibilityLabel("Agregar páginas")
                }
                .padding()
            }

            Button("Continuar a edición") { goToEdit = true }
                .buttonStyle(.primaryFilled)
                .disabled(session.pages.isEmpty)
                .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(session.pages.count == 1 ? "1 página" : "\(session.pages.count) páginas")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView(
                onFinish: { session.addCapturedPages($0); showScanner = false },
                onCancel: { showScanner = false }
            )
            .ignoresSafeArea()
        }
        .navigationDestination(isPresented: $goToEdit) {
            NewDocumentEditView(session: session, onSaved: onDone)
        }
    }

    private func pageCell(_ page: PageEditState, index: Int) -> some View {
        Image(uiImage: page.original)
            .resizable()
            .aspectRatio(3.0 / 4.0, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .bottomLeading) {
                Text("\(index + 1)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(8)
            }
            .overlay(alignment: .topTrailing) {
                Button { session.removePage(at: index) } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.bold())
                        .padding(6)
                        .background(.black.opacity(0.55), in: Circle())
                        .foregroundStyle(.white)
                }
                .padding(6)
                .accessibilityLabel("Eliminar página \(index + 1)")
            }
            .contextMenu {
                Button { session.movePage(at: index, by: -1) } label: {
                    Label("Mover antes", systemImage: "arrow.left")
                }
                .disabled(index == 0)
                Button { session.movePage(at: index, by: 1) } label: {
                    Label("Mover después", systemImage: "arrow.right")
                }
                .disabled(index == session.pages.count - 1)
                Button(role: .destructive) { session.removePage(at: index) } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            }
    }
}
