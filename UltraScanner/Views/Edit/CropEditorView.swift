import SwiftUI

/// Recortar: the whole page with the document's four corners. Drag them to the document's edges;
/// on Listo the page is straightened to what's inside (PageRenderer.cropped).
struct CropEditorView: View {
    let page: PageEditState
    let onDone: (PageQuad?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    /// Corners as shown, on the page turned like the preview.
    @State private var quad = PageQuad.full
    @State private var dragStart: CGPoint?
    @State private var notFound = false

    private static let space = "crop-page"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Arrastra las esquinas hasta los bordes del documento.")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                canvas

                HStack(spacing: 12) {
                    toolButton("Toda la página", systemImage: "arrow.up.left.and.arrow.down.right") {
                        quad = .full
                    }
                    toolButton("Detectar bordes", systemImage: "viewfinder") {
                        detect()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle("Recortar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        onDone(quad == .full ? nil : quad.rotated(quarterTurns: -page.quarterTurns))
                        dismiss()
                    }
                    .bold()
                }
            }
            .alert("No se encontró un documento en la foto.", isPresented: $notFound) {
                Button("OK", role: .cancel) {}
            }
        }
        .task {
            let page = page
            image = await Task.detached(priority: .userInitiated) { page.cropSource() }.value
            quad = (page.crop ?? .full).rotated(quarterTurns: page.quarterTurns)
        }
    }

    // MARK: - Page and corners

    private var canvas: some View {
        GeometryReader { geometry in
            if let image {
                let size = fittedSize(image.size, in: geometry.size)
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: size.width, height: size.height)
                    // Dims what's left out.
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: size))
                        path.addLines(quad.corners.map { point($0, in: size) })
                        path.closeSubpath()
                    }
                    .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                    Path { path in
                        path.addLines(quad.corners.map { point($0, in: size) })
                        path.closeSubpath()
                    }
                    .stroke(Color.accentColor, lineWidth: 2)
                    ForEach(0..<4, id: \.self) { index in
                        handle(index, in: size)
                    }
                }
                .frame(width: size.width, height: size.height)
                .coordinateSpace(.named(Self.space))
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            } else {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(28)
    }

    private func handle(_ index: Int, in size: CGSize) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 3))
            .frame(width: 26, height: 26)
            .frame(width: 48, height: 48)
            .contentShape(Circle())
            .position(point(quad.corners[index], in: size))
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        let start = dragStart ?? quad.corners[index]
                        dragStart = start
                        var corners = quad.corners
                        corners[index] = CGPoint(
                            x: min(max(start.x + value.translation.width / size.width, 0), 1),
                            y: min(max(start.y + value.translation.height / size.height, 0), 1))
                        quad.corners = corners
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .accessibilityLabel("Esquina \(index + 1)")
    }

    private func point(_ fraction: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: fraction.x * size.width, y: fraction.y * size.height)
    }

    private func fittedSize(_ imageSize: CGSize, in bounds: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func detect() {
        guard let image else { return }
        Task {
            let found = await Task.detached(priority: .userInitiated) { DocumentDetector.detect(in: image) }.value
            if let found { quad = found } else { notFound = true }
        }
    }

    private func toolButton(_ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
