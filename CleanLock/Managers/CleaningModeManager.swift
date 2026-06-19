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
    private let pointerDeviceSeizer: PointerDeviceSeizer
    private let cursorController: CursorController
    private let idleSleepAssertion: IdleSleepAssertion
    private let sessionStore: CleaningSessionStore
    private var autoUnlockTimer: Timer?
    private var unlockCompletionTask: Task<Void, Never>?

    private convenience init() {
        self.init(
            inputBlocker: InputBlocker(),
            overlayManager: OverlayManager(),
            preferences: PreferencesStore.shared,
            pointerDeviceSeizer: PointerDeviceSeizer(),
            cursorController: CursorController(),
            idleSleepAssertion: IdleSleepAssertion(),
            sessionStore: CleaningSessionStore()
        )
    }

    init(
        inputBlocker: InputBlocker,
        overlayManager: OverlayManager,
        preferences: PreferencesStore,
        pointerDeviceSeizer: PointerDeviceSeizer,
        cursorController: CursorController,
        idleSleepAssertion: IdleSleepAssertion,
        sessionStore: CleaningSessionStore
    ) {
        self.inputBlocker = inputBlocker
        self.overlayManager = overlayManager
        self.preferences = preferences
        self.pointerDeviceSeizer = pointerDeviceSeizer
        self.cursorController = cursorController
        self.idleSleepAssertion = idleSleepAssertion
        self.sessionStore = sessionStore

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

        let interval = preferences.autoUnlockDuration.timeInterval
        do {
            try activateLayers(autoUnlockInterval: interval)
            sessionStore.cleaningEndsAt = Date().addingTimeInterval(interval)
            state = .active
        } catch {
            teardownActiveLayers()
            state = .inactive
            showMessage(
                title: text(.cleaningModeNotStarted),
                message: error.localizedDescription
            )
        }
    }

    private func activateLayers(autoUnlockInterval: TimeInterval) throws {
        try overlayManager.showOverlay(
            displayScope: preferences.displayScope,
            autoUnlockDuration: preferences.autoUnlockDuration,
            remainingOverride: autoUnlockInterval
        )
        pointerDeviceSeizer.start()
        cursorController.hideAndFreezeCursor()
        try inputBlocker.start()
        idleSleepAssertion.begin()
        scheduleAutoUnlock(after: autoUnlockInterval)
    }

    private func teardownActiveLayers() {
        autoUnlockTimer?.invalidate()
        autoUnlockTimer = nil
        inputBlocker.stop()
        pointerDeviceSeizer.stop()
        cursorController.restoreCursor()
        overlayManager.hideOverlay()
        idleSleepAssertion.end()
    }

    func stopCleaningMode() {
        guard state.isActive else { return }

        unlockCompletionTask?.cancel()
        unlockCompletionTask = nil
        state = .stopping
        teardownActiveLayers()
        sessionStore.clear()
        state = .inactive
    }

    func handleSystemWillSleep() {
        pauseCleaning()
    }

    func handleSessionLocked() {
        pauseCleaning()
    }

    func handleSessionUnlocked() {
        attemptResume()
    }

    func handleSystemDidWake() {
        attemptResume()
    }

    /// Re-applies a persisted cleaning session at launch (survives a crash).
    func reconcilePersistedSession() {
        attemptResume()
    }

    /// Tears down the active layers but KEEPS the persisted deadline, so the
    /// session can resume on unlock/wake. Used for lock and sleep (interruptions
    /// that an app cannot prevent), as opposed to stopCleaningMode() which ends it.
    private func pauseCleaning() {
        guard state.isActive else { return }

        unlockCompletionTask?.cancel()
        unlockCompletionTask = nil
        teardownActiveLayers()
        state = .inactive
    }

    /// Resumes a paused session if there is remaining time and the screen is not
    /// locked. Silent (no prompt). Continues the remaining time, never restarts.
    private func attemptResume() {
        guard !state.isActive else { return }
        guard let endsAt = sessionStore.cleaningEndsAt else { return }

        let remaining = endsAt.timeIntervalSinceNow
        guard remaining > 0 else {
            sessionStore.clear()
            return
        }

        guard !SessionLockObserver.isScreenLocked else { return }

        let permissionManager = PermissionManager.shared
        permissionManager.checkPermissions()
        guard permissionManager.canAttemptCleaningMode else {
            sessionStore.clear()
            return
        }

        state = .starting
        do {
            try activateLayers(autoUnlockInterval: remaining)
            state = .active
        } catch {
            teardownActiveLayers()
            sessionStore.clear()
            state = .inactive
        }
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
        switch state {
        case .active, .unlocking:
            break
        case .inactive, .starting, .stopping:
            return
        }

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
        pointerDeviceSeizer.stop()
        cursorController.restoreCursor()
        idleSleepAssertion.end()
        sessionStore.clear()
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

    private func scheduleAutoUnlock(after interval: TimeInterval) {
        autoUnlockTimer?.invalidate()
        autoUnlockTimer = nil

        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopCleaningMode()
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        autoUnlockTimer = timer
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
