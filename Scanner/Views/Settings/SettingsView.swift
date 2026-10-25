import SwiftUI

/// Matches the Ajustes options agreed in the design canvas. Deliberately NO "Exportar
/// todo" / backup option, and NO OCR language picker (OCR always runs with the device
/// language + English — see TextRecognizer).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_lock_enabled") private var appLockEnabled = true
    @State private var defaultFormat: ExportFormat = .pdf
    @State private var storageUsedText = "Calculando…"

    var body: some View {
        NavigationStack {
            List {
                Section("Seguridad") {
                    Toggle("Bloquear con Face ID al abrir", isOn: $appLockEnabled)
                }

                Section("Exportación") {
                    Picker("Formato por defecto", selection: $defaultFormat) {
                        Text("PDF").tag(ExportFormat.pdf)
                        Text("JPG").tag(ExportFormat.jpg)
                    }
                }

                Section("Almacenamiento") {
                    LabeledContent("Espacio usado", value: storageUsedText)
                }

                Section("Cámara") {
                    Button("Abrir ajustes de permisos del sistema") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section {
                    LabeledContent("Versión", value: "1.0.0")
                } header: {
                    Text("Acerca de")
                } footer: {
                    Text("Todo se guarda cifrado en este dispositivo. No hay copia de seguridad en la nube: si pierdes el teléfono, se pierden los documentos.")
                }
            }
            .navigationTitle("Ajustes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onAppear { computeStorageUsed() }
        }
    }

    private func computeStorageUsed() {
        storageUsedText = "—"
    }
}
