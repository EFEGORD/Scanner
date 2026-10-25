import SwiftUI

/// Matches Camara.dc.html + Revision.dc.html: presents VisionKit's scanner, keeps a
/// running batch count, then hands off to the review/edit/export steps before returning
/// to the Biblioteca.
struct ScanCaptureView: View {
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session = ScanSessionViewModel()
    @State private var showReview = false

    var body: some View {
        NavigationStack {
            DocumentScannerView(
                onFinish: { images in
                    session.addCapturedPages(images)
                    showReview = true
                },
                onCancel: { dismiss() }
            )
            .ignoresSafeArea()
            .navigationDestination(isPresented: $showReview) {
                PageReviewView(session: session, onDone: {
                    onDone()
                    dismiss()
                })
            }
        }
    }
}
