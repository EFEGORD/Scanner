import SwiftUI
import UIKit

/// Matches Compartir.dc.html: pick PDF/JPG, then one "Compartir" button. The interstitial ad
/// shows first, then the native iOS share sheet (WhatsApp, Correo, AirDrop, Drive…) opens.
struct ShareDocumentView: View {
    let document: ScanDocument

    @Environment(\.dismiss) private var dismiss
    @AppStorage("default_export_format") private var defaultFormat: ExportFormat = .pdf
    @State private var format: ExportFormat = .pdf
    @State private var isPreparing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Compartir documento")
                    .font(.title3.bold())
                Text(document.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Formato")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("Formato", selection: $format) {
                    Text("PDF").tag(ExportFormat.pdf)
                    Text("JPG").tag(ExportFormat.jpg)
                }
                .pickerStyle(.segmented)
            }

            Text("Al tocar Compartir se abre el menú de iOS para enviarlo por WhatsApp, Correo, AirDrop o la app que elijas.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer(minLength: 0)

            Button(action: share) {
                if isPreparing {
                    ProgressView().tint(.white)
                } else {
                    Text("Compartir")
                }
            }
            .buttonStyle(.primaryFilled)
            .disabled(isPreparing)
        }
        .padding(24)
        .onAppear { format = defaultFormat }
    }

    private func share() {
        isPreparing = true
        errorMessage = nil
        AdManager.shared.beforeSharing {
            Task { @MainActor in await present() }
        }
    }

    private func present() async {
        do {
            let urls = try await ExportService.makeShareFiles(for: document, format: format)
            let activity = UIActivityViewController(activityItems: urls, applicationActivities: nil)
            activity.completionWithItemsHandler = { _, completed, _, _ in
                if completed {
                    AppAnalytics.log(.documentShared, ["format": format.rawValue])
                }
                ExportService.cleanUp(urls)
                dismiss()
            }
            isPreparing = false
            UIApplication.topViewController()?.present(activity, animated: true)
        } catch {
            isPreparing = false
            errorMessage = String(localized: "No se pudo preparar el archivo para compartir.")
        }
    }
}
