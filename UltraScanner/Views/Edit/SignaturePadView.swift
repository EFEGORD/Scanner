import SwiftUI
import PencilKit

/// Draw a signature with the finger (PencilKit), or reuse the saved one.
struct SignaturePadView: View {
    let onUse: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var canvas = PKCanvasView()
    @State private var isEmpty = true
    @State private var savedSignature: UIImage?
    @State private var remember = true

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let savedSignature {
                    Button {
                        onUse(savedSignature)
                        dismiss()
                    } label: {
                        HStack {
                            Image(uiImage: savedSignature)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 44)
                                .padding(6)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                            Spacer()
                            Text("Usar firma guardada")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Text("O dibuja una nueva:")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                SignatureCanvas(canvas: canvas, isEmpty: $isEmpty)
                    .frame(height: 220)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(.systemGray4)))
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color(.systemGray3))
                            .frame(height: 1)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 52)
                            .allowsHitTesting(false)
                    }

                Toggle("Guardar para la próxima vez", isOn: $remember)

                Spacer()

                Button("Usar esta firma") { use() }
                    .buttonStyle(.primaryFilled)
                    .disabled(isEmpty)
            }
            .padding()
            .navigationTitle("Firma")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Borrar") {
                        canvas.drawing = PKDrawing()
                        isEmpty = true
                    }
                    .disabled(isEmpty)
                }
            }
            .task { savedSignature = SignatureStore.loadSaved() }
        }
    }

    private func use() {
        let drawing = canvas.drawing
        guard !drawing.bounds.isEmpty else { return }
        // Render with the light appearance: in dark mode PencilKit would invert black ink to white.
        var image = UIImage()
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: drawing.bounds.insetBy(dx: -8, dy: -8), scale: 3)
        }
        if remember { SignatureStore.save(image) }
        onUse(image)
        dismiss()
    }
}

private struct SignatureCanvas: UIViewRepresentable {
    let canvas: PKCanvasView
    @Binding var isEmpty: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.overrideUserInterfaceStyle = .light
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isEmpty: $isEmpty)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var isEmpty: Binding<Bool>

        init(isEmpty: Binding<Bool>) {
            self.isEmpty = isEmpty
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            isEmpty.wrappedValue = canvasView.drawing.bounds.isEmpty
        }
    }
}
