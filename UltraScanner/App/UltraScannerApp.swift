import SwiftUI
import GoogleMobileAds

@main
struct UltraScannerApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var appLock = AppLockManager.shared

    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasCompletedOnboarding {
                    LibraryView()
                } else {
                    OnboardingFlowView(onFinished: {
                        hasCompletedOnboarding = true
                        // The user just went through setup; don't ask for Face ID right away.
                        appLock.markUnlocked()
                    })
                }

                if appLock.isLocked && hasCompletedOnboarding {
                    LockScreenView()
                        .transition(.opacity)
                }
            }
            .onAppear {
                appLock.lockIfNeeded()
                _ = AdManager.shared // loads the first interstitial so it's ready at the first save
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                appLock.lockIfNeeded()
            }
        }
    }
}

/// Minimal full-screen cover shown while the app is locked; kicks off Face ID immediately.
private struct LockScreenView: View {
    @StateObject private var appLock = AppLockManager.shared

    // Matches Bloqueo.dc.html.
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 112, height: 112)
                    Image(systemName: "faceid")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.accentColor)
                }
                VStack(spacing: 8) {
                    Text("UltraScanner está bloqueado")
                        .font(.title2.bold())
                    Text("Usa Face ID para ver tus documentos.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Desbloquear con Face ID") { authenticate() }
                .buttonStyle(.primaryFilled)
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear { authenticate() }
    }

    private func authenticate() {
        appLock.authenticate { _ in }
    }
}
