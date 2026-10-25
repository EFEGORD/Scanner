import SwiftUI

/// Matches Editar.dc.html: dark editor with the page, filter pills and Rotar / Firmar.
/// Used for a new scan (before saving) and for a document that's already saved.
struct PageEditorView: View {
    @Binding var pages: [PageEditState]
    let primaryTitle: String
    var isBusy = false
    let onPrimary: () -> Void

    @State private var currentIndex = 0
    @State private var previews: [UUID: UIImage] = [:]
    @State private var showSignaturePad = false

    private struct FilterOption: Identifiable {
        let filter: PageFilter
        let title: String
        var id: String { filter.rawValue }
    }

    private let filters = [
        FilterOption(filter: .original, title: "Original"),
        FilterOption(filter: .color, title: "Color"),
        FilterOption(filter: .blackAndWhite, title: "Blanco y negro"),
        FilterOption(filter: .magic, title: "Magia"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            if pages.indices.contains(currentIndex) {
                pageCanvas
                pageSwitcher
                filterPills
                toolbar
            } else {
                Spacer()
            }

            Button(action: onPrimary) {
                if isBusy {
                    ProgressView().tint(.white)
                } else {
                    Text(primaryTitle)
                }
            }
            .buttonStyle(.primaryFilled)
            .disabled(isBusy || pages.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color.black.ignoresSafeArea())
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationTitle("Editar")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: previewKey) { await refreshPreview() }
        .sheet(isPresented: $showSignaturePad) {
            SignaturePadView { image in
                pages[currentIndex].signatures.append(
                    PlacedSignature(image: image, center: CGPoint(x: 0.68, y: 0.84), widthFraction: 0.38))
            }
        }
    }

    // MARK: - Page

    /// Changes whenever the current page's preview must be re-rendered.
    private var previewKey: String {
        guard pages.indices.contains(currentIndex) else { return "" }
        let page = pages[currentIndex]
        return "\(page.id)-\(page.filter.rawValue)-\(page.quarterTurns)"
    }

    private func refreshPreview() async {
        guard pages.indices.contains(currentIndex) else { return }
        let page = pages[currentIndex]
        let image = await Task.detached(priority: .userInitiated) { page.preview() }.value
        previews[page.id] = image
    }

    private var pageCanvas: some View {
        GeometryReader { geometry in
            let page = pages[currentIndex]
            if let preview = previews[page.id] {
                let size = fittedSize(preview.size, in: geometry.size)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: preview)
                        .resizable()
                        .frame(width: size.width, height: size.height)
                    ForEach($pages[currentIndex].signatures) { $signature in
                        SignatureOverlay(signature: $signature, pageSize: size) {
                            pages[currentIndex].signatures.removeAll { $0.id == signature.id }
                        }
                    }
                }
                .frame(width: size.width, height: size.height)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }

    private func fittedSize(_ imageSize: CGSize, in bounds: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    @ViewBuilder
    private var pageSwitcher: some View {
        if pages.count > 1 {
            HStack(spacing: 20) {
                Button { currentIndex -= 1 } label: { Image(systemName: "chevron.left") }
                    .disabled(currentIndex == 0)
                    .accessibilityLabel("Página anterior")
                Text("Página \(currentIndex + 1) de \(pages.count)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Button { currentIndex += 1 } label: { Image(systemName: "chevron.right") }
                    .disabled(currentIndex == pages.count - 1)
                    .accessibilityLabel("Página siguiente")
            }
            .foregroundStyle(.white)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Filters

    private var filterPills: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters) { option in
                        let isSelected = pages[currentIndex].filter == option.filter
                        Button { pages[currentIndex].filter = option.filter } label: {
                            Text(option.title)
                                .font(.subheadline.weight(isSelected ? .bold : .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.accentColor : Color.white.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(Color.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            if pages.count > 1 {
                Button("Aplicar este filtro a todas las páginas") {
                    let filter = pages[currentIndex].filter
                    for index in pages.indices { pages[index].filter = filter }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.75))
            }
        }
        .padding(.bottom, 14)
    }

    // MARK: - Tools

    private var toolbar: some View {
        HStack {
            toolButton("Rotar", systemImage: "rotate.right") {
                pages[currentIndex].quarterTurns += 1
                // Signature positions are relative to the page as drawn; after a rotation
                // they'd land somewhere else, so they're cleared.
                pages[currentIndex].signatures.removeAll()
            }
            toolButton("Firmar", systemImage: "signature") {
                showSignaturePad = true
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 14)
    }

    private func toolButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.title3)
                Text(title).font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
        }
    }
}

/// A signature on the page: drag to move, pinch to resize, ✕ to remove.
private struct SignatureOverlay: View {
    @Binding var signature: PlacedSignature
    let pageSize: CGSize
    let onDelete: () -> Void

    @State private var dragStart: CGPoint?
    @State private var widthStart: CGFloat?

    var body: some View {
        let frame = signature.frame(in: pageSize)
        Image(uiImage: signature.image)
            .resizable()
            .frame(width: frame.width, height: frame.height)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
            )
            .overlay(alignment: .topTrailing) {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.white, Color.red)
                }
                .offset(x: 12, y: -12)
                .accessibilityLabel("Quitar firma")
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = dragStart ?? signature.center
                        if dragStart == nil { dragStart = start }
                        signature.center = CGPoint(
                            x: min(max(start.x + value.translation.width / pageSize.width, 0), 1),
                            y: min(max(start.y + value.translation.height / pageSize.height, 0), 1))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { scale in
                        let start = widthStart ?? signature.widthFraction
                        if widthStart == nil { widthStart = start }
                        signature.widthFraction = min(max(start * scale, 0.1), 0.9)
                    }
                    .onEnded { _ in widthStart = nil }
            )
            .position(x: frame.midX, y: frame.midY)
    }
}
