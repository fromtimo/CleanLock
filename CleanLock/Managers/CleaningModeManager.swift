import AppKit
import Foundation

@MainActor
final class CleaningModeManager: ObservableObject {
    static let shared = CleaningModeManager()

    @Published private(set) var state: CleaningModeState = .inactive {
        didSet {
            onStateChange?(state)
        }
    }

    var onStateChange: ((CleaningModeState) -> Void)?
    var onPermissionsRequired: (() -> Void)?

    var isCleaningModeActive: Bool {
        state.isActive
    }

    private let inputBlocker: InputBlocker
    private let overlayManager: OverlayManager
    private let preferences: PreferencesStore
    private var autoUnlockTimer: Timer?

    private convenience init() {
        self.init(
            inputBlocker: InputBlocker(),
            overlayManager: OverlayManager(),
            preferences: PreferencesStore.shared
        )
    }

    init(
        inputBlocker: InputBlocker,
        overlayManager: OverlayManager,
        preferences: PreferencesStore
    ) {
        self.inputBlocker = inputBlocker
        self.overlayManager = overlayManager
        self.preferences = preferences

        self.inputBlocker.onCommandStateChanged = { [weak self] commandState in
            Task { @MainActor in
                self?.handleCommandStateChanged(commandState)
            }
        }

        self.inputBlocker.onUnlockCompleted = { [weak self] in
            Task { @MainActor in
                self?.stopCleaningMode()
            }
        }

        self.inputBlocker.onFailure = { [weak self] message in
            Task { @MainActor in
                self?.stopCleaningModeAfterFailure(message: message)
            }
        }
    }

    func startCleaningMode() {
        guard !state.isActive else { return }

        state = .starting

        let permissionManager = PermissionManager.shared
        permissionManager.checkPermissions()

        guard permissionManager.canAttemptCleaningMode else {
            state = .inactive
            onPermissionsRequired?()
            return
        }

        do {
            try overlayManager.showOverlay(displayScope: preferences.displayScope)
            try inputBlocker.start()
            scheduleAutoUnlockIfNeeded()
            state = .active
        } catch {
            autoUnlockTimer?.invalidate()
            autoUnlockTimer = nil
            inputBlocker.stop()
            overlayManager.hideOverlay()
            state = .inactive
            showMessage(
                title: "Режим очистки не запущен",
                message: error.localizedDescription
            )
        }
    }

    func stopCleaningMode() {
        guard state.isActive else { return }

        state = .stopping
        autoUnlockTimer?.invalidate()
        autoUnlockTimer = nil
        inputBlocker.stop()
        overlayManager.hideOverlay()
        state = .inactive
    }

    func handleSystemWillSleep() {
        stopCleaningMode()
    }

    func handleDisplayConfigurationChanged() {
        guard state.isActive else { return }

        stopCleaningMode()
        showMessage(
            title: "Режим очистки был отключён",
            message: "Изменился набор экранов. CleanLock вернул управление."
        )
    }

    private func handleCommandStateChanged(_ commandState: CommandKeyState) {
        overlayManager.updateCommandKeyState(commandState)

        guard state.isActive else { return }

        if commandState.progress > 0 {
            state = .unlocking(progress: commandState.progress)
        } else {
            state = .active
        }
    }

    private func stopCleaningModeAfterFailure(message: String) {
        let wasActive = state.isActive
        stopCleaningMode()

        if wasActive {
            showMessage(
                title: "Режим очистки был отключён",
                message: message
            )
        }
    }

    private func scheduleAutoUnlockIfNeeded() {
        autoUnlockTimer?.invalidate()
        autoUnlockTimer = nil

        let interval = preferences.autoUnlockDuration.timeInterval

        autoUnlockTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopCleaningMode()
            }
        }
    }

    private func showMessage(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
