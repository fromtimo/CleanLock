// CleanLock/Managers/SessionLockObserver.swift
import AppKit
import CoreGraphics

/// Translates macOS session lock/unlock into clean callbacks, isolating the
/// UNDOCUMENTED distributed-notification names behind a stable interface.
/// Best-effort: Apple may change these names in a future macOS version.
@MainActor
final class SessionLockObserver {
    var onLocked: (() -> Void)?
    var onUnlocked: (() -> Void)?

    private let center = DistributedNotificationCenter.default()
    private var tokens: [NSObjectProtocol] = []

    /// `true` if the session is locked right now (used to reconcile at launch).
    static var isScreenLocked: Bool {
        guard let info = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }
        return (info["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }

    func start() {
        guard tokens.isEmpty else { return }
        tokens.append(subscribe("com.apple.screenIsLocked"))
        tokens.append(subscribe("com.apple.screenIsUnlocked"))
    }

    func stop() {
        tokens.forEach { center.removeObserver($0) }
        tokens.removeAll()
    }

    private func subscribe(_ name: String) -> NSObjectProtocol {
        center.addObserver(
            forName: Notification.Name(name),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if name == "com.apple.screenIsLocked" {
                    self.onLocked?()
                } else {
                    self.onUnlocked?()
                }
            }
        }
    }
}
