import SwiftUI

/// The 6-step tutorial. Matches the Main.dc.html → Tutorial2..6.dc.html flow in the
/// design canvas: swipeable pages, progress dots, "Omitir" skips straight to the
/// Biblioteca, "Comenzar" on the last slide moves on to the camera permission screen.
struct OnboardingFlowView: View {
    let onFinished: () -> Void

    @State private var currentIndex = 0
    @State private var goToPermissions = false

    private let slides = OnboardingSlide.all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Omitir") { onFinished() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding()

                TabView(selection: $currentIndex) {
                    ForEach(slides) { slide in
                        TutorialPageView(slide: slide).tag(slide.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 24) {
                    HStack(spacing: 8) {
                        ForEach(slides) { slide in
                            Capsule()
                                .fill(slide.id == currentIndex ? Color.accentColor : Color(.systemGray4))
                                .frame(width: slide.id == currentIndex ? 20 : 6, height: 6)
                        }
                    }

                    Button {
                        if currentIndex == slides.count - 1 {
                            goToPermissions = true
                        } else {
                            withAnimation { currentIndex += 1 }
                        }
                    } label: {
                        if currentIndex == slides.count - 1 {
                            Text("Comenzar")
                        } else {
                            Text("Siguiente")
                        }
                    }
                    .buttonStyle(.primaryFilled)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
            .navigationDestination(isPresented: $goToPermissions) {
                CameraPermissionView(onFinished: onFinished)
            }
        }
    }
}
