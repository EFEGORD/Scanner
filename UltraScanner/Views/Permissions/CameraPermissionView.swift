import SwiftUI
import AVFoundation

struct CameraPermissionView: View {
    let onFinished: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 120, height: 120)
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 10) {
                Text("Permite el acceso a la cámara")
                    .font(.title3.bold())
                Text("La usamos solo para escanear. Tus fotos nunca salen de tu teléfono.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 36)

            Spacer()

            VStack(spacing: 14) {
                Button("Permitir acceso") { requestAccess() }
                    .buttonStyle(.primaryFilled)
                Button("Ahora no") { onFinished() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 44)
        }
        .navigationBarBackButtonHidden(false)
    }

    private func requestAccess() {
        AVCaptureDevice.requestAccess(for: .video) { _ in
            DispatchQueue.main.async { onFinished() }
        }
    }
}
