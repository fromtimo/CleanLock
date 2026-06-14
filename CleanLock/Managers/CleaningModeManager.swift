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
    private var unlockCompletionTask: Task<Void, Never>?

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
                self?.completeUnlockAndStopCleaningMode()
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

        unlockCompletionTask?.cancel()
        unlockCompletionTask = nil
        state = .starting

        let permissionManager = PermissionManager.shared
        permissionManager.checkPermissions()

        guard permissionManager.canAttemptCleaningMode else {
            state = .inactive
            onPermissionsRequired?()
            return
        }

        do {
            try overlayManager.showOverlay(
                displayScope: preferences.displayScope,
                autoUnlockDuration: preferences.autoUnlockDuration
            )
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
                title: text(.cleaningModeNotStarted),
                message: error.localizedDescription
            )
        }
    }

    func stopCleaningMode() {
        guard state.isActive else { return }

        unlockCompletionTask?.cancel()
        unlockCompletionTask = nil
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
            title: text(.cleaningModeDisabled),
            message: text(.displayConfigurationChanged)
        )
    }

    private func handleCommandStateChanged(_ commandState: CommandKeyState) {
        guard state.isActive else { return }

        overlayManager.updateCommandKeyState(commandState)

        if commandState.progress > 0 {
            state = .unlocking(progress: commandState.progress)
        } else {
            state = .active
        }
    }

    private func completeUnlockAndStopCleaningMode() {
        guard state.isActive else { return }

        state = .stopping
        autoUnlockTimer?.invalidate()
        autoUnlockTimer = nil
        inputBlocker.stop()
        overlayManager.markUnlockCompleted()

        unlockCompletionTask?.cancel()
        unlockCompletionTask = Task { @MainActor in
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            let delay: UInt64 = reduceMotion ? 150_000_000 : 450_000_000
            try? await Task.sleep(nanoseconds: delay)

            guard !Task.isCancelled else { return }

            overlayManager.hideOverlay()
            state = .inactive
            unlockCompletionTask = nil
        }
    }

    private func stopCleaningModeAfterFailure(message: String) {
        let wasActive = state.isActive
        stopCleaningMode()

        if wasActive {
            showMessage(
                title: text(.cleaningModeDisabled),
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

    private func text(_ key: AppStrings.Key) -> String {
        AppStrings.text(key, language: preferences.appLanguage)
    }
}
