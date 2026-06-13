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
final class OverlayState: ObservableObject {
    @Published var commandKeyState: CommandKeyState = .inactive
    @Published var backgroundOpacity: Double = 0
    @Published var showsContent = false
    @Published var contentYOffset: CGFloat = 18
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
    private var cleanupTask: Task<Void, Never>?
    private var entranceTask: Task<Void, Never>?

    func showOverlay(displayScope: DisplayScope) throws {
        hideOverlay(immediately: true)

        let screens = selectedScreens(for: displayScope)
        guard !screens.isEmpty else {
            throw OverlayError.noScreens
        }

        let mainScreen = NSScreen.main ?? screens[0]
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let backgroundDuration = reduceMotion ? 0.15 : 1.5
        let contentDelay: TimeInterval = reduceMotion ? 0 : 1.15
        let contentDuration: TimeInterval = reduceMotion ? 0.15 : 1

        records = screens.map { screen in
            let state = OverlayState()
            state.contentYOffset = reduceMotion ? 0 : 18
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
            }
        }
    }

    func updateCommandKeyState(_ state: CommandKeyState) {
        guard isShowing else { return }

        for record in records where record.showsMainUI {
            record.state.commandKeyState = state
        }
    }

    func hideOverlay(immediately: Bool = false) {
        entranceTask?.cancel()
        entranceTask = nil
        cleanupTask?.cancel()
        cleanupTask = nil

        guard !records.isEmpty else {
            isShowing = false
            return
        }

        let activeRecords = records
        records = []
        isShowing = false

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let fadeDuration = immediately ? 0 : (reduceMotion ? 0.15 : 0.6)

        withAnimation(.easeOut(duration: fadeDuration)) {
            for record in activeRecords {
                record.state.showsContent = false
                record.state.contentYOffset = reduceMotion ? 0 : 8
                record.state.backgroundOpacity = 0
            }
        }

        cleanupTask = Task { @MainActor in
            let delay = UInt64(max(fadeDuration, 0) * 1_000_000_000)
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }

            for record in activeRecords {
                record.window.orderOut(nil)
                record.window.close()
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
        let window = NSWindow(
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
