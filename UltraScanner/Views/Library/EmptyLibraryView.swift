import SwiftUI

/// First-run state of the Biblioteca (Vacia.dc.html in the design canvas).
struct EmptyLibraryView: View {
    let onScan: () -> Void
    let onImportPhotos: () -> Void
    let onImportFiles: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 8) {
                Text("Aún no tienes documentos")
                    .font(.title3.bold())
                Text("Escanea tu primer documento. Se guarda cifrado y solo en este teléfono.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onScan) {
                    Label("Escanear documento", systemImage: "doc.viewfinder")
                }
                .buttonStyle(.primaryFilled)

                Menu {
                    Button(action: onImportPhotos) {
                        Label("Fotos", systemImage: "photo.on.rectangle")
                    }
                    Button(action: onImportFiles) {
                        Label("Archivos", systemImage: "folder")
                    }
                } label: {
                    Label("Importar fotos o PDF", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .menuOrder(.fixed)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }
}
