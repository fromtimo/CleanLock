import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hasCompletedOnboarding = PreferencesStore.shared.hasCompletedOnboarding
        NSApp.setActivationPolicy(hasCompletedOnboarding ? .accessory : .regular)

        let menuBarController = MenuBarController(cleaningModeManager: .shared)
        menuBarController.install()
        self.menuBarController = menuBarController
        installSystemObservers()

        if !hasCompletedOnboarding {
            menuBarController.showOnboarding()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        CleaningModeManager.shared.stopCleaningMode()
    }

    private func installSystemObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func handleWillSleep() {
        CleaningModeManager.shared.handleSystemWillSleep()
    }

    @objc private func handleScreenParametersChanged() {
        CleaningModeManager.shared.handleDisplayConfigurationChanged()
    }
}
