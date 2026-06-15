import AppKit
import CoreGraphics
import Foundation

@MainActor
final class CursorController {
    private var isCursorHidden = false
    private var isCursorDisconnected = false

    func hideAndFreezeCursor() {
        NSApp.activate(ignoringOtherApps: true)

        if !isCursorDisconnected {
            let result = CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
            if result == .success {
                isCursorDisconnected = true
            }
        }

        if !isCursorHidden {
            let result = CGDisplayHideCursor(CGMainDisplayID())
            if result == .success {
                isCursorHidden = true
            }
        }
    }

    func restoreCursor() {
        restoreCursorState()
    }

    private func restoreCursorState() {
        if isCursorDisconnected {
            _ = CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
            isCursorDisconnected = false
        }

        if isCursorHidden {
            _ = CGDisplayShowCursor(CGMainDisplayID())
            isCursorHidden = false
        }
    }

    deinit {
        if isCursorDisconnected {
            _ = CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        }

        if isCursorHidden {
            _ = CGDisplayShowCursor(CGMainDisplayID())
        }
    }
}
