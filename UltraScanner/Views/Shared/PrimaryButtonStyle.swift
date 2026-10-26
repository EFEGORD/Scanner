import SwiftUI

/// The full-width rounded button used across every mockup (Comenzar / Siguiente / Guardar /
/// Continuar...), in the Ultra gradient (Theme.swift).
struct PrimaryFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.ultraGradient, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryFilledButtonStyle {
    static var primaryFilled: PrimaryFilledButtonStyle { PrimaryFilledButtonStyle() }
}
