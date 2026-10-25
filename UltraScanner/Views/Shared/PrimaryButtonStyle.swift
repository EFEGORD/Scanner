import SwiftUI

/// Matches the blue, full-width rounded button used across every mockup
/// (Comenzar / Siguiente / Guardar / Continuar...).
struct PrimaryFilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryFilledButtonStyle {
    static var primaryFilled: PrimaryFilledButtonStyle { PrimaryFilledButtonStyle() }
}
