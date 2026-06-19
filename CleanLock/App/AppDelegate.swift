import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private let sessionLockObserver = SessionLockObserver()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hasCompletedOnboarding = PreferencesStore.shared.hasCompletedOnboarding
        NSApp.setActivationPolicy(hasCompletedOnboarding ? .accessory : .regular)

        let menuBarController = MenuBarController(cleaningModeManager: .shared)
        menuBarController.install()
        self.menuBarController = menuBarController
        installSystemObservers()
        CleaningModeManager.shared.reconcilePersistedSession()

        if !hasCompletedOnboarding {
            menuBarController.showOnboarding()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        CleaningModeManager.shared.handleAppWillTerminate()
    }

    private func installSystemObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        sessionLockObserver.onLocked = {
            CleaningModeManager.shared.handleSessionLocked()
        }
        sessionLockObserver.onUnlocked = {
            CleaningModeManager.shared.handleSessionUnlocked()
        }
        sessionLockObserver.start()
    }

    @objc private func handleWillSleep() {
        CleaningModeManager.shared.handleSystemWillSleep()
    }

    @objc private func handleDidWake() {
        CleaningModeManager.shared.handleSystemDidWake()
    }

    @objc private func handleScreenParametersChanged() {
        CleaningModeManager.shared.handleDisplayConfigurationChanged()
    }
}
