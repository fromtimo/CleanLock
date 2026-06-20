// CleanLock/Managers/CleaningSessionStore.swift
import Foundation

/// Persists the deadline of an in-progress cleaning session so it can be
/// resumed after a screen lock, a sleep, or even a process crash.
/// Single responsibility: read/write `cleaningEndsAt` in UserDefaults.
@MainActor
final class CleaningSessionStore {
    private enum Keys {
        static let cleaningEndsAt = "cleaningModeEndsAt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Absolute time at which the active cleaning session should end.
    /// `nil` when there is no persisted session.
    var cleaningEndsAt: Date? {
        get {
            let timestamp = defaults.double(forKey: Keys.cleaningEndsAt)
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: Keys.cleaningEndsAt)
            } else {
                defaults.removeObject(forKey: Keys.cleaningEndsAt)
            }
        }
    }

    func clear() {
        defaults.removeObject(forKey: Keys.cleaningEndsAt)
    }
}
