import AppKit
import ApplicationServices
import Foundation
import IOKit.hid

enum PermissionState: Equatable {
    case notGranted
    case granted
    case requiresRestart
    case requiresManualCheck

    var title: String {
        title(language: .current)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .notGranted:
            return AppStrings.text(.notGranted, language: language)
        case .granted:
            return AppStrings.text(.granted, language: language)
        case .requiresRestart:
            return AppStrings.text(.requiresRestart, language: language)
        case .requiresManualCheck:
            return AppStrings.text(.requiresManualCheck, language: language)
        }
    }
}

@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published private(set) var accessibilityStatus: PermissionState = .notGranted
    @Published private(set) var inputMonitoringStatus: PermissionState = .notGranted

    var hasRequiredPermissions: Bool {
        accessibilityStatus == .granted && inputMonitoringStatus == .granted
    }

    var canAttemptCleaningMode: Bool {
        hasRequiredPermissions
    }

    var permissionIssueMessage: String {
        let language = PreferencesStore.shared.appLanguage

        if accessibilityStatus != .granted {
            return AppStrings.text(.permissionIssueAccessibility, language: language)
        }

        if inputMonitoringStatus == .notGranted {
            return AppStrings.text(.permissionIssueInputMonitoring, language: language)
        }

        return AppStrings.text(.permissionIssueGeneric, language: language)
    }

    var canContinuePastPermissionStep: Bool {
        hasRequiredPermissions
    }

    private init() {
        checkPermissions()
    }

    func checkPermissions() {
        accessibilityStatus = AXIsProcessTrusted() ? .granted : .notGranted
        inputMonitoringStatus = Self.currentInputMonitoringStatus()
    }

    func refresh() {
        checkPermissions()
    }

    func openSystemSettingsForPermissions() {
        if accessibilityStatus != .granted {
            openAccessibilitySettings()
        } else {
            openInputMonitoringSettings()
        }
    }

    func openAccessibilitySettings() {
        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openSystemSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    func openRequiredSettings() {
        openSystemSettingsForPermissions()
    }

    private func openSystemSettingsPane(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private static func currentInputMonitoringStatus() -> PermissionState {
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)

        switch access {
        case kIOHIDAccessTypeGranted:
            return .granted
        case kIOHIDAccessTypeDenied:
            return .notGranted
        case kIOHIDAccessTypeUnknown:
            return .requiresManualCheck
        default:
            return .requiresManualCheck
        }
    }
}
