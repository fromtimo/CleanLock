import AppKit
import Foundation
import SwiftUI

enum OverlayError: LocalizedError {
    case noScreens

    var errorDescription: String? {
        switch self {
        case .noScreens:
            return AppStrings.text(.overlayNoScreens)
        }
    }
}

@MainActor
final class CleaningOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class OverlayState: ObservableObject {
    @Published var commandKeyState: CommandKeyState = .inactive
    @Published var backgroundOpacity: Double = 0
    @Published var showsContent = false
    @Published var contentYOffset: CGFloat = 18
    @Published var lockIconState: AnimatedLockIconState = .unlocked
    @Published var isUnlockCompleted = false
    @Published var autoUnlockRemainingSeconds: Int?
}

@MainActor
final class OverlayManager {
    private struct OverlayWindowRecord {
        let window: NSWindow
        let state: OverlayState
        let showsMainUI: Bool
    }

    private(set) var isShowing = false
    private var records: [OverlayWindowRecord] = []
    private var closingRecords: [OverlayWindowRecord] = []
    private var cleanupTask: Task<Void, Never>?
    private var entranceTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?

    func showOverlay(
        displayScope: DisplayScope,
        autoUnlockDuration: AutoUnlockDuration,
        remainingOverride: TimeInterval? = nil
    ) throws {
        hideOverlay(immediately: true)

        let screens = selectedScreens(for: displayScope)
        guard !screens.isEmpty else {
            throw OverlayError.noScreens
        }

        let mainScreen = NSScreen.main ?? screens[0]
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let backgroundDuration = reduceMotion ? 0.15 : 0.8
        let contentDelay: TimeInterval = reduceMotion ? 0 : 0.40
        let contentDuration: TimeInterval = reduceMotion ? 0.15 : 0.6
        let countdownDuration = remainingOverride ?? autoUnlockDuration.timeInterval
        let autoUnlockSeconds = Int(countdownDuration.rounded(.up))

        records = screens.map { screen in
            let state = OverlayState()
            state.contentYOffset = reduceMotion ? 0 : 18
            state.autoUnlockRemainingSeconds = autoUnlockSeconds
            let showsMainUI = isSameScreen(screen, mainScreen)
            let contentView: AnyView = showsMainUI
                ? AnyView(CleaningOverlayView(state: state))
                : AnyView(OverlayBackgroundView(state: state))
            let hostingController = NSHostingController(rootView: contentView)
            hostingController.view.frame = NSRect(origin: .zero, size: screen.frame.size)
            hostingController.view.autoresizingMask = [.width, .height]
            let window = makeOverlayWindow(for: screen, hostingController: hostingController)

            return OverlayWindowRecord(
                window: window,
                state: state,
                showsMainUI: showsMainUI
            )
        }

        isShowing = true

        for record in records {
            record.window.orderFrontRegardless()
        }

        NSApp.activate(ignoringOtherApps: true)

        if let mainWindow = records.first(where: \.showsMainUI)?.window {
            mainWindow.makeKeyAndOrderFront(nil)
        }

        withAnimation(.easeInOut(duration: backgroundDuration)) {
            for record in records {
                record.state.backgroundOpacity = 1
            }
        }

        entranceTask = Task { @MainActor in
            let delay = UInt64(contentDelay * 1_000_000_000)
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }

            guard !Task.isCancelled, isShowing else { return }

            if let mainRecord = records.first(where: \.showsMainUI) {
                withAnimation(.easeOut(duration: contentDuration)) {
                    mainRecord.state.showsContent = true
                    mainRecord.state.contentYOffset = 0
                }

                if !reduceMotion {
                    let lockStartDelay = contentDuration * 0.35
                    try? await Task.sleep(nanoseconds: UInt64(lockStartDelay * 1_000_000_000))
                }

                guard !Task.isCancelled, isShowing else { return }

                mainRecord.state.lockIconState = .locking

                if !reduceMotion {
                    let lockDuration = AnimatedLockIconTiming.lockingDuration
                    try? await Task.sleep(nanoseconds: UInt64(lockDuration * 1_000_000_000))
                }

                guard !Task.isCancelled, isShowing else { return }
                mainRecord.state.lockIconState = .locked
            }
        }

        startAutoUnlockCountdown(duration: countdownDuration)
    }

    func updateCommandKeyState(_ state: CommandKeyState) {
        guard isShowing else { return }

        for record in records where record.showsMainUI {
            record.state.commandKeyState = state
        }
    }

    func markUnlockCompleted() {
        guard isShowing else { return }

        countdownTask?.cancel()
        countdownTask = nil

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.04)) {
            for record in records where record.showsMainUI {
                record.state.commandKeyState = CommandKeyState(
                    isLeftCommandPressed: true,
                    isRightCommandPressed: true,
                    progress: 1
                )
                record.state.isUnlockCompleted = true
            }
        }
    }

    func hideOverlay(immediately: Bool = false) {
        entranceTask?.cancel()
        entranceTask = nil
        countdownTask?.cancel()
        countdownTask = nil
        cleanupTask?.cancel()
        cleanupTask = nil
        closeClosingRecords()

        guard !records.isEmpty else {
            isShowing = false
            return
        }

        let activeRecords = records
        records = []
        closingRecords = activeRecords
        isShowing = false

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let fadeDuration = immediately ? 0 : (reduceMotion ? 0.15 : 0.6)
        let shouldAnimateUnlock = !immediately
            && !reduceMotion
            && activeRecords.contains { $0.showsMainUI && $0.state.showsContent }
        let unlockDuration = shouldAnimateUnlock ? AnimatedLockIconTiming.unlockingDuration : 0

        if immediately || reduceMotion {
            for record in activeRecords where record.showsMainUI {
                record.state.lockIconState = .unlocked
            }
        } else if shouldAnimateUnlock {
            for record in activeRecords where record.showsMainUI {
                record.state.lockIconState = .unlocking
            }
        }

        cleanupTask = Task { @MainActor in
            let unlockDelay = UInt64(max(unlockDuration, 0) * 1_000_000_000)
            if unlockDelay > 0 {
                try? await Task.sleep(nanoseconds: unlockDelay)
            }

            guard !Task.isCancelled else { return }

            for record in activeRecords where record.showsMainUI {
                record.state.lockIconState = .unlocked
            }

            withAnimation(.easeOut(duration: fadeDuration)) {
                for record in activeRecords {
                    record.state.showsContent = false
                    record.state.contentYOffset = reduceMotion ? 0 : 8
                    record.state.backgroundOpacity = 0
                    record.state.autoUnlockRemainingSeconds = nil
                }
            }

            let fadeDelay = UInt64(max(fadeDuration, 0) * 1_000_000_000)
            if fadeDelay > 0 {
                try? await Task.sleep(nanoseconds: fadeDelay)
            }

            guard !Task.isCancelled else { return }

            for record in activeRecords {
                close(record)
            }

            closingRecords.removeAll { closingRecord in
                activeRecords.contains { $0.window === closingRecord.window }
            }
        }
    }

    private func startAutoUnlockCountdown(duration: TimeInterval) {
        countdownTask?.cancel()

        countdownTask = Task { @MainActor in
            let startedAt = Date()
            let totalSeconds = max(Int(duration.rounded(.up)), 0)

            while !Task.isCancelled, isShowing {
                let elapsed = max(Int(Date().timeIntervalSince(startedAt).rounded(.down)), 0)
                let remainingSeconds = max(totalSeconds - elapsed, 0)

                for record in records where record.showsMainUI {
                    record.state.autoUnlockRemainingSeconds = remainingSeconds
                }

                guard remainingSeconds > 0 else { return }

                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
            }
        }
    }

    private func selectedScreens(for displayScope: DisplayScope) -> [NSScreen] {
        switch displayScope {
        case .allDisplays:
            return NSScreen.screens
        case .mainDisplay:
            return NSScreen.main.map { [$0] } ?? []
        }
    }

    private func makeOverlayWindow(
        for screen: NSScreen,
        hostingController: NSHostingController<AnyView>
    ) -> NSWindow {
        let window = CleaningOverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.contentViewController = hostingController
        window.setFrame(screen.frame, display: true)
        window.contentMinSize = screen.frame.size
        window.contentMaxSize = screen.frame.size
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.canHide = false
        window.isReleasedWhenClosed = false

        return window
    }

    private func isSameScreen(_ lhs: NSScreen, _ rhs: NSScreen) -> Bool {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        let lhsNumber = lhs.deviceDescription[key] as? NSNumber
        let rhsNumber = rhs.deviceDescription[key] as? NSNumber

        if let lhsNumber, let rhsNumber {
            return lhsNumber == rhsNumber
        }

        return lhs.frame == rhs.frame
    }

    private func closeClosingRecords() {
        guard !closingRecords.isEmpty else { return }

        for record in closingRecords {
            close(record)
        }

        closingRecords = []
    }

    private func close(_ record: OverlayWindowRecord) {
        record.window.orderOut(nil)
        record.window.close()
    }
}

private struct OverlayBackgroundView: View {
    @ObservedObject var state: OverlayState

    var body: some View {
        ZStack {
            Color.black
                .opacity(state.backgroundOpacity)
                .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
