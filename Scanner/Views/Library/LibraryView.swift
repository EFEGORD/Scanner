import SwiftUI

/// Matches Home.dc.html: title + search/combinar/ajustes icons, folder chips, document
/// list, floating "+" to scan, bottom tab bar.
struct LibraryView: View {
    @StateObject private var viewModel = LibraryViewModel()
    @State private var showScanner = false
    @State private var showCombine = false
    @State private var showSettings = false
    @State private var showNewFolderPrompt = false
    @State private var newFolderName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                folderChips
                documentList
            }
            .background(Color(.systemGroupedBackground))
            .overlay(alignment: .bottomTrailing) { scanFAB }
            .onAppear { viewModel.load() }
            .fullScreenCover(isPresented: $showScanner) {
                ScanCaptureView(onDone: { viewModel.load() })
            }
            .sheet(isPresented: $showCombine) {
                CombineDocumentsView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("Nueva carpeta", isPresented: $showNewFolderPrompt) {
                TextField("Nombre", text: $newFolderName)
                Button("Cancelar", role: .cancel) {}
                Button("Crear") {
                    viewModel.createFolder(name: newFolderName)
                    newFolderName = ""
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Mis documentos").font(.largeTitle.bold())
            Spacer()
            Button { } label: { Image(systemName: "magnifyingglass") }
            Button { showCombine = true } label: { Image(systemName: "rectangle.on.rectangle") }
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
        }
        .buttonStyle(.iconChip)
        .padding()
    }

    private var folderChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(title: "Todos", isSelected: viewModel.selectedFolderId == nil) {
                    viewModel.selectFolder(nil)
                }
                ForEach(viewModel.folders) { folder in
                    chip(title: folder.name, isSelected: viewModel.selectedFolderId == folder.id) {
                        viewModel.selectFolder(folder.id)
                    }
                }
                chip(title: "+", isSelected: false) { showNewFolderPrompt = true }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 14)
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemBackground),
                            in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
    }

    private var documentList: some View {
        List {
            ForEach(viewModel.documents) { document in
                NavigationLink(value: document) {
                    DocumentRowView(document: document)
                }
            }
            .onDelete { indexSet in
                indexSet.forEach { viewModel.delete(viewModel.documents[$0]) }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: ScanDocument.self) { document in
            DocumentEditView(document: document)
        }
    }

    private var scanFAB: some View {
        Button { showScanner = true } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Color.accentColor, in: Circle())
                .shadow(color: .accentColor.opacity(0.35), radius: 10, y: 6)
        }
        .padding()
    }
}

private struct DocumentRowView: View {
    let document: ScanDocument

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 48, height: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text(document.title).font(.subheadline.weight(.bold))
                Text(document.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct IconChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 38, height: 38)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private extension ButtonStyle where Self == IconChipButtonStyle {
    static var iconChip: IconChipButtonStyle { IconChipButtonStyle() }
}
