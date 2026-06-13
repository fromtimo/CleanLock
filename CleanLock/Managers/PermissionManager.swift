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
        switch self {
        case .notGranted:
            return "Не выдано"
        case .granted:
            return "Выдано"
        case .requiresRestart:
            return "Требуется перезапуск"
        case .requiresManualCheck:
            return "Требуется проверка"
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
        if accessibilityStatus != .granted {
            return "CleanLock нужен доступ «Универсальный доступ», чтобы временно блокировать ввод во время режима очистки."
        }

        if inputMonitoringStatus == .notGranted {
            return "CleanLock нужен доступ «Мониторинг ввода», чтобы определить удержание левой и правой Command для выхода."
        }

        return "Проверь разрешения macOS для CleanLock и попробуй снова."
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
