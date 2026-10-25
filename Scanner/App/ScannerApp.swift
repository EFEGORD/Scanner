import SwiftUI

@main
struct ScannerApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var appLock = AppLockManager.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasCompletedOnboarding {
                    LibraryView()
                } else {
                    OnboardingFlowView(onFinished: { hasCompletedOnboarding = true })
                }

                if appLock.isLocked && hasCompletedOnboarding {
                    LockScreenView()
                        .transition(.opacity)
                }
            }
            .onAppear { appLock.lockIfNeeded() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                appLock.lockIfNeeded()
            }
        }
    }
}

/// Minimal full-screen cover shown while the app is locked; kicks off Face ID immediately.
private struct LockScreenView: View {
    @StateObject private var appLock = AppLockManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            Text("Scanner está bloqueado")
                .font(.headline)
            Button("Desbloquear") { authenticate() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear { authenticate() }
    }

    private func authenticate() {
        appLock.authenticate { _ in }
    }
}
