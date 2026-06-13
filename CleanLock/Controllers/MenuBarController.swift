import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let cleaningModeManager: CleaningModeManager
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?

    init(cleaningModeManager: CleaningModeManager) {
        self.cleaningModeManager = cleaningModeManager
        super.init()
    }

    func install() {
        cleaningModeManager.onStateChange = { [weak self] _ in
            self?.rebuildMenu()
        }
        cleaningModeManager.onPermissionsRequired = { [weak self] in
            self?.showOnboarding(initialStep: .permissions)
        }

        installStatusItemIfNeeded()
    }

    func showOnboarding(initialStep: OnboardingStep = .welcome) {
        NSApp.setActivationPolicy(.regular)

        if let onboardingWindow {
            if initialStep == .permissions {
                onboardingWindow.close()
                self.onboardingWindow = nil
            } else {
                onboardingWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }

        let view = OnboardingView(initialStep: initialStep) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            self?.installStatusItemIfNeeded()
            NSApp.setActivationPolicy(.accessory)
        }

        let window = makeWindow(
            title: "CleanLock",
            size: NSSize(width: 560, height: 500),
            rootView: view
        )
        window.delegate = self

        onboardingWindow = window
        centerWindowOnMainScreen(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func installStatusItemIfNeeded() {
        guard statusItem == nil else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusButton()
        rebuildMenu()
    }

    private func configureStatusButton() {
        guard let button = statusItem?.button else { return }

        let image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "CleanLock")
        image?.isTemplate = true
        button.image = image
    }

    private func rebuildMenu() {
        guard let statusItem else { return }

        let menu = NSMenu()

        if cleaningModeManager.isCleaningModeActive {
            let activeItem = NSMenuItem(title: "Режим очистки включён", action: nil, keyEquivalent: "")
            activeItem.isEnabled = false
            menu.addItem(activeItem)
        } else {
            menu.addItem(NSMenuItem(
                title: "Включить режим очистки",
                action: #selector(startCleaningMode),
                keyEquivalent: ""
            ))
        }

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(
            title: "Настройки",
            action: #selector(showSettings),
            keyEquivalent: ""
        )
        settingsItem.isEnabled = PreferencesStore.shared.hasCompletedOnboarding
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem(
            title: "Выйти",
            action: #selector(quitApplication),
            keyEquivalent: ""
        ))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
    }

    @objc private func startCleaningMode() {
        guard PreferencesStore.shared.hasCompletedOnboarding else {
            showOnboarding()
            return
        }

        cleaningModeManager.startCleaningMode()
    }

    @objc private func showSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = makeWindow(
            title: "Настройки CleanLock",
            size: NSSize(width: 520, height: 380),
            rootView: SettingsView()
        )
        window.delegate = self

        settingsWindow = window
        centerWindowOnMainScreen(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApplication() {
        cleaningModeManager.stopCleaningMode()
        NSApp.terminate(nil)
    }

    private func makeWindow<Content: View>(
        title: String,
        size: NSSize,
        rootView: Content
    ) -> NSWindow {
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.setContentSize(size)
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        return window
    }

    private func centerWindowOnMainScreen(_ window: NSWindow) {
        guard let screen = NSScreen.main else {
            window.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - windowSize.width / 2,
            y: visibleFrame.midY - windowSize.height / 2
        )

        window.setFrameOrigin(origin)
    }
}

extension MenuBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if window === onboardingWindow {
            onboardingWindow = nil

            if PreferencesStore.shared.hasCompletedOnboarding {
                NSApp.setActivationPolicy(.accessory)
            }
        }

        if window === settingsWindow {
            settingsWindow = nil
        }
    }
}
