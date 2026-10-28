import SwiftUI

/// An imported PDF or image goes through the same review → edit / sign → save steps as a scan
/// (ScanCaptureView), starting at the review.
struct ImportBatch: Identifiable {
    let id = UUID()
    let session: ScanSessionViewModel
    let truncated: Bool
}

struct ImportFlowView: View {
    let batch: ImportBatch
    @Environment(\.dismiss) private var dismiss
    @State private var showTruncatedNotice = false

    var body: some View {
        NavigationStack {
            PageReviewView(session: batch.session, onDone: { dismiss() })
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                }
        }
        .onAppear { showTruncatedNotice = batch.truncated }
        .alert("Se importaron las primeras \(DocumentImporter.maxPages) páginas", isPresented: $showTruncatedNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Para un documento más largo, impórtalo en partes y únelas con Combinar.")
        }
    }
}
