import SwiftUI

struct TutorialPageView: View {
    let slide: OnboardingSlide

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 148, height: 148)
                Image(systemName: slide.systemImage)
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 12) {
                Text(slide.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(slide.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
