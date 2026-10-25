import SwiftUI
import AVFoundation

/// Matches Ajustes.dc.html. Deliberately NO "Exportar todo" / backup option and NO OCR
/// language picker (OCR always runs with the device language + English).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("app_lock_enabled") private var appLockEnabled = true
    @AppStorage("default_export_format") private var defaultFormat: ExportFormat = .pdf
    @State private var storageUsed = "Calculando…"
    @State private var hasSignature = false

    var body: some View {
        NavigationStack {
            List {
                Section("Seguridad") {
                    Toggle("Bloquear con Face ID", isOn: $appLockEnabled)
                }

                Section("Documentos") {
                    Picker("Formato al compartir", selection: $defaultFormat) {
                        Text("PDF").tag(ExportFormat.pdf)
                        Text("JPG").tag(ExportFormat.jpg)
                    }
                    NavigationLink("Carpetas") { FoldersView() }
                    LabeledContent("Firma guardada", value: hasSignature ? "Guardada" : "Ninguna")
                    if hasSignature {
                        Button("Borrar firma guardada", role: .destructive) {
                            SignatureStore.deleteSaved()
                            hasSignature = false
                        }
                    }
                }

                Section("Dispositivo") {
                    LabeledContent("Espacio usado", value: storageUsed)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        LabeledContent("Permiso de cámara", value: cameraStatusText)
                    }
                    .tint(Color.primary)
                }

                Section {
                    LabeledContent("Versión", value: appVersion)
                } footer: {
                    Text("Tus documentos se guardan cifrados solo en este teléfono. No hay copia en la nube: si pierdes el teléfono, se pierden tus documentos.")
                }
            }
            .navigationTitle("Ajustes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .task { await refresh() }
        }
    }

    private var cameraStatusText: String {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return "Permitido"
        case .denied, .restricted: return "Denegado"
        case .notDetermined: return "Sin pedir"
        @unknown default: return "—"
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func refresh() async {
        hasSignature = (try? DocumentRepository.shared.savedSignature()) != nil
        let bytes = await Task.detached(priority: .utility) { Self.documentsSize() }.value
        storageUsed = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// Everything the app keeps lives under Documents (encrypted pages + the SQLite file).
    private static func documentsSize() -> Int64 {
        guard let root = try? FileManager.default.url(
                for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false),
              let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey])
        else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }
}

/// Create / delete folders. Deleting a folder keeps its documents (they become "Sin carpeta").
struct FoldersView: View {
    @State private var folders: [ScanFolder] = []
    @State private var showNew = false
    @State private var newName = ""

    var body: some View {
        List {
            Section {
                if folders.isEmpty {
                    Text("Aún no tienes carpetas.")
                        .foregroundStyle(.secondary)
                }
                ForEach(folders) { folder in
                    Text(folder.name)
                }
                .onDelete { offsets in
                    for index in offsets {
                        try? DocumentRepository.shared.deleteFolder(id: folders[index].id)
                    }
                    load()
                }
            } footer: {
                Text("Al borrar una carpeta, sus documentos se conservan y quedan en \"Sin carpeta\".")
            }
        }
        .navigationTitle("Carpetas")
        .toolbar {
            Button { showNew = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("Nueva carpeta")
        }
        .alert("Nueva carpeta", isPresented: $showNew) {
            TextField("Nombre", text: $newName)
            Button("Cancelar", role: .cancel) { newName = "" }
            Button("Crear") { create() }
        }
        .onAppear(perform: load)
    }

    private func load() {
        folders = (try? DocumentRepository.shared.allFolders()) ?? []
    }

    private func create() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        newName = ""
        guard !name.isEmpty else { return }
        _ = try? DocumentRepository.shared.createFolder(name: name)
        load()
    }
}
