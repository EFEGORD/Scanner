import Foundation
import LocalAuthentication
import Combine

/// Gates the app behind Face ID / Touch ID / passcode whenever it comes back to the
/// foreground. On by default (see Ajustes) — the encryption alone doesn't stop someone
/// who picks up an already-unlocked phone from opening the app and browsing documents.
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    @Published private(set) var isLocked: Bool = true

    /// Persisted in `settings` (key "app_lock_enabled"); defaults to true.
    var isEnabled: Bool {
        get { SettingsStore.shared.bool(forKey: "app_lock_enabled", default: true) }
        set { SettingsStore.shared.set(newValue, forKey: "app_lock_enabled") }
    }

    private init() {}

    func lockIfNeeded() {
        guard isEnabled else { isLocked = false; return }
        isLocked = true
    }

    func markUnlocked() {
        isLocked = false
    }

    func authenticate(completion: @escaping (Bool) -> Void) {
        guard isEnabled else {
            isLocked = false
            completion(true)
            return
        }

        let context = LAContext()
        var error: NSError?
        let policy: LAPolicy = .deviceOwnerAuthentication // falls back to passcode if biometrics unavailable

        guard context.canEvaluatePolicy(policy, error: &error) else {
            // No biometrics/passcode configured on the device: don't lock the user out.
            isLocked = false
            completion(true)
            return
        }

        context.evaluatePolicy(policy, localizedReason: "Desbloquea UltraScanner para ver tus documentos") { success, _ in
            DispatchQueue.main.async {
                self.isLocked = !success
                completion(success)
            }
        }
    }
}
