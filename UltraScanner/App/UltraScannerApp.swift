import SwiftUI

@main
struct UltraScannerApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var appLock = AppLockManager.shared

    #if DEBUG
    @State private var demoReady = !DemoMode.isActive
    #endif

    init() {
        AppAnalytics.start()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if !demoReady {
                ProgressView()
                    .task {
                        await DemoMode.prepare()
                        hasCompletedOnboarding = DemoMode.screen != "security"
                        appLock.markUnlocked()
                        demoReady = true
                    }
            } else {
                content
            }
            #else
            content
            #endif
        }
    }

    private var content: some View {
        ZStack {
            if hasCompletedOnboarding {
                LibraryView()
            } else {
                OnboardingFlowView(onFinished: {
                    hasCompletedOnboarding = true
                    AppAnalytics.log(.onboardingFinished)
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
            AdManager.shared.prepareIfConsented()
        }
        .task { await DocumentTypeBackfill.run() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            appLock.lockIfNeeded()
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
