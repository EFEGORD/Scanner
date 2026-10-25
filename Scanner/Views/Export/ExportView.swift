import SwiftUI
import UIKit

/// Matches Exportar.dc.html: nombre, carpeta, formato (siempre máxima calidad), y
/// compartir. El anuncio intersticial se muestra justo antes de abrir el share sheet,
/// y también al tocar "Guardar en Mis documentos" — nunca en ningún otro momento.
struct ExportView: View {
    let document: ScanDocument
    let onFinished: () -> Void

    @State private var format: ExportFormat
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    init(document: ScanDocument, onFinished: @escaping () -> Void) {
        self.document = document
        self.onFinished = onFinished
        _format = State(initialValue: document.exportFormat)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Formato").font(.caption.bold()).foregroundStyle(.secondary)
            Picker("Formato", selection: $format) {
                Text("PDF").tag(ExportFormat.pdf)
                Text("JPG").tag(ExportFormat.jpg)
            }
            .pickerStyle(.segmented)

            Text("Compartir").font(.caption.bold()).foregroundStyle(.secondary)
            HStack(spacing: 20) {
                shareIcon("message.fill", label: "WhatsApp")
                shareIcon("envelope.fill", label: "Email")
                shareIcon("tray.and.arrow.up.fill", label: "Drive")
                shareIcon("wifi", label: "Cerca (AirDrop)")
            }

            Spacer()

            Button("Guardar en Mis documentos") {
                AdManager.shared.showIfReady(from: UIApplication.topViewController()) {
                    onFinished()
                }
            }
            .buttonStyle(.primaryFilled)
        }
        .padding()
        .navigationTitle("Exportar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            ActivityView(items: shareItems)
        }
    }

    private func shareIcon(_ systemImage: String, label: String) -> some View {
        Button {
            prepareShare()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 46, height: 46)
                    .background(Color(.systemGray6), in: Circle())
                Text(label).font(.caption2.weight(.semibold))
            }
        }
        .foregroundStyle(.primary)
    }

    private func prepareShare() {
        AdManager.shared.showIfReady(from: UIApplication.topViewController()) {
            buildShareFile()
            showShareSheet = true
        }
    }

    private func buildShareFile() {
        // Decrypt pages, build the PDF/JPG into a TEMPORARY plaintext file, hand it to the
        // share sheet, and delete it right after — see ExportService (next pass) for the
        // full implementation wired to DocumentRepository + PDFGenerator.
        shareItems = []
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private extension UIApplication {
    static func topViewController() -> UIViewController {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        return root ?? UIViewController()
    }
}
