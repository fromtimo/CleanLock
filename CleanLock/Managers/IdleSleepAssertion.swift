// CleanLock/Managers/IdleSleepAssertion.swift
import Foundation
import IOKit.pwr_mgt

/// Keeps the display awake while active, so the screensaver / idle auto-lock
/// never fires during cleaning mode. Single responsibility: wrap one IOPMAssertion.
/// NOTE: This only blocks IDLE sleep. A manual power-button / lid-close (forced
/// sleep) cannot be prevented by any app — that case is handled by pause/resume.
@MainActor
final class IdleSleepAssertion {
    private var assertionID: IOPMAssertionID = IOPMAssertionID(0)
    private var isActive = false

    func begin() {
        guard !isActive else { return }
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "CleanLock cleaning mode" as CFString,
            &id
        )
        guard result == kIOReturnSuccess else { return }
        assertionID = id
        isActive = true
    }

    func end() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = IOPMAssertionID(0)
        isActive = false
    }
}
