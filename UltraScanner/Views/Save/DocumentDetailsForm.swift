import SwiftUI

/// Name + folder fields, shared by "Guardar documento" (new scan) and "Combinar".
struct DocumentDetailsForm: View {
    @Binding var title: String
    @Binding var selectedFolderId: String?
    var titleHint: String? = nil

    @State private var folders: [ScanFolder] = []
    @State private var showNewFolder = false
    @State private var newFolderName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nombre")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Nombre del documento", text: $title)
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                if let titleHint {
                    Text(titleHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Carpeta")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        folderChip("Sin carpeta", id: nil)
                        ForEach(folders) { folder in
                            folderChip(folder.name, id: folder.id)
                        }
                        Button { showNewFolder = true } label: {
                            Text("+ Carpeta")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .overlay(
                                    Capsule().strokeBorder(Color(.systemGray3), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                                )
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Nueva carpeta")
                    }
                }
            }

            Label("Se guarda cifrado, solo en este teléfono.", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(Color.green)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .onAppear(perform: loadFolders)
        .alert("Nueva carpeta", isPresented: $showNewFolder) {
            TextField("Nombre", text: $newFolderName)
            Button("Cancelar", role: .cancel) { newFolderName = "" }
            Button("Crear") { createFolder() }
        }
    }

    private func folderChip(_ name: String, id: String?) -> some View {
        let isSelected = selectedFolderId == id
        return Button { selectedFolderId = id } label: {
            Text(name)
                .font(.subheadline.weight(isSelected ? .bold : .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
    }

    private func loadFolders() {
        folders = (try? DocumentRepository.shared.allFolders()) ?? []
    }

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        newFolderName = ""
        guard !name.isEmpty, let folder = try? DocumentRepository.shared.createFolder(name: name) else { return }
        loadFolders()
        selectedFolderId = folder.id
    }
}
