import Foundation

/// Simple on-device preferences (Face ID toggle, default export format, etc.).
/// Backed by UserDefaults — plain app preferences, not sensitive document content,
/// so they don't need the encrypted store. Still never leaves the device.
final class SettingsStore {
    static let shared = SettingsStore()
    private let defaults = UserDefaults.standard
    private init() {}

    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if defaults.object(forKey: key) == nil { return defaultValue }
        return defaults.bool(forKey: key)
    }

    func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func set(_ value: String?, forKey key: String) {
        defaults.set(value, forKey: key)
    }
}
