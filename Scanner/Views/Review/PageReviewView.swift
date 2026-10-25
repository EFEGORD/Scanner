import SwiftUI

/// Matches Revision.dc.html: grid of captured pages, reorder/delete, "Dividir"/"Combinar"
/// affordances (full split/merge UI lands once a document already exists — here we're
/// still assembling the very first save), "+ Agregar" to scan another page.
struct PageReviewView: View {
    @ObservedObject var session: ScanSessionViewModel
    let onDone: () -> Void

    @State private var showScanner = false
    @State private var goToEdit = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 0) {
            Text("\(session.capturedImages.count) páginas")
                .font(.headline)
                .padding(.top)

            Text("Mantén presionada una página para reordenarla.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(session.capturedImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(3.0/4.0, contentMode: .fill)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(alignment: .bottomLeading) {
                                    Text("\(index + 1)")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8).padding(.vertical, 2)
                                        .background(Color.accentColor, in: Capsule())
                                        .foregroundStyle(.white)
                                        .padding(8)
                                }

                            Button {
                                session.removePage(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2.bold())
                                    .padding(6)
                                    .background(.black.opacity(0.55), in: Circle())
                                    .foregroundStyle(.white)
                            }
                            .padding(6)
                        }
                    }

                    Button { showScanner = true } label: {
                        VStack {
                            Image(systemName: "plus")
                            Text("Agregar").font(.caption.bold())
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(3.0/4.0, contentMode: .fit)
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6])))
                    }
                }
                .padding()
            }

            Button("Continuar a edición") { goToEdit = true }
                .buttonStyle(.primaryFilled)
                .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showScanner) {
            NavigationStack {
                DocumentScannerView(
                    onFinish: { session.addCapturedPages($0); showScanner = false },
                    onCancel: { showScanner = false }
                )
                .ignoresSafeArea()
            }
        }
        .navigationDestination(isPresented: $goToEdit) {
            NewDocumentEditView(session: session, onSaved: onDone)
        }
    }
}
