import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case russian = "ru"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english:
            return "English"
        case .russian:
            return "Русский"
        }
    }

    static var defaultForSystem: AppLanguage {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferredLanguage.hasPrefix("ru") ? .russian : .english
    }

    static var current: AppLanguage {
        if let rawValue = UserDefaults.standard.string(forKey: PreferencesStore.Keys.appLanguage),
           let language = AppLanguage(rawValue: rawValue) {
            return language
        }

        return defaultForSystem
    }
}

enum AppStrings {
    static func text(_ key: Key, language: AppLanguage = .current) -> String {
        switch language {
        case .english:
            return englishText(for: key)
        case .russian:
            return russianText(for: key)
        }
    }

    private static func englishText(for key: Key) -> String {
        switch key {
        case .notGranted:
            return "Not granted"
        case .granted:
            return "Granted"
        case .requiresRestart:
            return "Restart required"
        case .requiresManualCheck:
            return "Check manually"
        case .permissionIssueAccessibility:
            return "CleanLock needs Accessibility access to temporarily block input during cleaning mode."
        case .permissionIssueInputMonitoring:
            return "CleanLock needs Input Monitoring access to detect holding left and right Command to exit."
        case .permissionIssueGeneric:
            return "Check CleanLock permissions in macOS and try again."
        case .autoUnlockFiveMinutes:
            return "5 minutes"
        case .autoUnlockTenMinutes:
            return "10 minutes"
        case .autoUnlockTwentyMinutes:
            return "20 minutes"
        case .displayScopeAllDisplays:
            return "All displays"
        case .displayScopeMainDisplay:
            return "Main display only"
        case .cleaningModeEnabled:
            return "Cleaning mode is on"
        case .startCleaningMode:
            return "Start cleaning mode"
        case .settings:
            return "Settings"
        case .quit:
            return "Quit"
        case .settingsWindowTitle:
            return "CleanLock Settings"
        case .welcomeSubtitle:
            return "Clean your MacBook keyboard and trackpad safely without accidental input."
        case .welcomeBody:
            return "CleanLock temporarily blocks keyboard and trackpad clicks, dims the screen, and shows a clear way to exit cleaning mode.\n\nCleanLock does not record keystrokes, use the internet, or collect analytics."
        case .continueButton:
            return "Continue"
        case .permissionsTitle:
            return "macOS permissions needed"
        case .permissionsDescription:
            return "To block accidental input and detect the unlock gesture, CleanLock needs system permissions."
        case .accessibilityTitle:
            return "Accessibility"
        case .accessibilityDescription:
            return "Allows CleanLock to block keyboard and trackpad events during cleaning mode."
        case .inputMonitoringTitle:
            return "Input Monitoring"
        case .inputMonitoringDescription:
            return "Allows CleanLock to detect holding both Command keys to exit cleaning mode."
        case .permissionsPrivacyNote:
            return "Keystrokes are not saved or sent anywhere. Permissions are used only for cleaning mode."
        case .backButton:
            return "Back"
        case .unlockTestTitle:
            return "Test unlock"
        case .unlockTestDescription:
            return "Hold the left and right Command keys for 3 seconds."
        case .leftCommand:
            return "Left ⌘"
        case .rightCommand:
            return "Right ⌘"
        case .unlockTestFootnote:
            return "Exiting requires left and right Command. If an external keyboard does not have right Command, or the shortcut does not work, cleaning mode will turn off automatically after the safety timeout."
        case .completedTitle:
            return "Setup complete"
        case .completedDescription:
            return "CleanLock is ready. You can start cleaning mode from the menu bar icon."
        case .doneButton:
            return "Done"
        case .openButton:
            return "Open"
        case .overlayTitle:
            return "Cleaning mode"
        case .overlayInputBlocked:
            return "Keyboard and clicks are blocked."
        case .overlayExitInstruction:
            return "To exit, hold left and right Command for 3 seconds."
        case .settingsTitle:
            return "Settings"
        case .launchAtLogin:
            return "Launch at login"
        case .language:
            return "Language"
        case .autoUnlock:
            return "Auto-unlock"
        case .autoUnlockSubtitle:
            return "Safety timer for exiting cleaning mode."
        case .displays:
            return "Displays"
        case .displaysSubtitle:
            return "Which displays to dim during cleaning mode."
        case .overlayNoScreens:
            return "Could not determine a display for cleaning mode."
        case .inputBlockerFailed:
            return "Could not start input blocking. Check Accessibility and Input Monitoring permissions."
        case .eventTapStopped:
            return "macOS stopped input handling. CleanLock returned control."
        case .cleaningModeNotStarted:
            return "Cleaning mode did not start"
        case .cleaningModeDisabled:
            return "Cleaning mode was turned off"
        case .displayConfigurationChanged:
            return "The display configuration changed. CleanLock returned control."
        }
    }

    private static func russianText(for key: Key) -> String {
        switch key {
        case .notGranted:
            return "Не выдано"
        case .granted:
            return "Выдано"
        case .requiresRestart:
            return "Требуется перезапуск"
        case .requiresManualCheck:
            return "Требуется проверка"
        case .permissionIssueAccessibility:
            return "CleanLock нужен доступ «Универсальный доступ», чтобы временно блокировать ввод во время режима очистки."
        case .permissionIssueInputMonitoring:
            return "CleanLock нужен доступ «Мониторинг ввода», чтобы определить удержание левой и правой Command для выхода."
        case .permissionIssueGeneric:
            return "Проверь разрешения macOS для CleanLock и попробуй снова."
        case .autoUnlockFiveMinutes:
            return "5 минут"
        case .autoUnlockTenMinutes:
            return "10 минут"
        case .autoUnlockTwentyMinutes:
            return "20 минут"
        case .displayScopeAllDisplays:
            return "Все экраны"
        case .displayScopeMainDisplay:
            return "Только главный экран"
        case .cleaningModeEnabled:
            return "Режим очистки включён"
        case .startCleaningMode:
            return "Включить режим очистки"
        case .settings:
            return "Настройки"
        case .quit:
            return "Выйти"
        case .settingsWindowTitle:
            return "Настройки CleanLock"
        case .welcomeSubtitle:
            return "Безопасно чисти клавиатуру и трекпад MacBook без случайных нажатий."
        case .welcomeBody:
            return "Утилита временно блокирует клавиатуру и клики по трекпаду, затемняет экран и показывает понятный способ выхода из режима очистки.\n\nCleanLock не записывает нажатия клавиш, не использует интернет и не собирает аналитику."
        case .continueButton:
            return "Продолжить"
        case .permissionsTitle:
            return "Нужны разрешения macOS"
        case .permissionsDescription:
            return "Чтобы блокировать случайные нажатия и определять сочетание для выхода из режима очистки, CleanLock нужны системные разрешения."
        case .accessibilityTitle:
            return "Универсальный доступ"
        case .accessibilityDescription:
            return "Позволяет CleanLock блокировать события клавиатуры и трекпада во время режима очистки."
        case .inputMonitoringTitle:
            return "Мониторинг ввода"
        case .inputMonitoringDescription:
            return "Позволяет CleanLock определять удержание двух клавиш Command для выхода из режима очистки."
        case .permissionsPrivacyNote:
            return "Нажатия не сохраняются и никуда не отправляются. Разрешения нужны только для работы режима блокировки."
        case .backButton:
            return "Назад"
        case .unlockTestTitle:
            return "Проверь разблокировку"
        case .unlockTestDescription:
            return "Удерживай левую и правую клавиши Command в течение 3 секунд."
        case .leftCommand:
            return "Левый ⌘"
        case .rightCommand:
            return "Правый ⌘"
        case .unlockTestFootnote:
            return "Для выхода нужны левая и правая Command. Если на внешней клавиатуре нет правой Command или сочетание не сработает, режим автоматически отключится по страховочному таймеру."
        case .completedTitle:
            return "Настройка завершена"
        case .completedDescription:
            return "CleanLock готов к использованию. Включить режим очистки можно через иконку в меню-баре."
        case .doneButton:
            return "Готово"
        case .openButton:
            return "Открыть"
        case .overlayTitle:
            return "Режим очистки"
        case .overlayInputBlocked:
            return "Клавиатура и клики заблокированы."
        case .overlayExitInstruction:
            return "Для выхода удерживай левую и правую Command 3 секунды."
        case .settingsTitle:
            return "Настройки"
        case .launchAtLogin:
            return "Запускать при входе"
        case .language:
            return "Язык"
        case .autoUnlock:
            return "Автоотключение"
        case .autoUnlockSubtitle:
            return "Страховочный таймер для выхода из режима очистки."
        case .displays:
            return "Экраны"
        case .displaysSubtitle:
            return "Какие экраны затемнять во время режима очистки."
        case .overlayNoScreens:
            return "Не удалось определить экран для режима очистки."
        case .inputBlockerFailed:
            return "Не удалось включить блокировку ввода. Проверь разрешения Accessibility и Input Monitoring."
        case .eventTapStopped:
            return "macOS остановила обработку ввода. CleanLock вернул управление."
        case .cleaningModeNotStarted:
            return "Режим очистки не запущен"
        case .cleaningModeDisabled:
            return "Режим очистки был отключён"
        case .displayConfigurationChanged:
            return "Изменился набор экранов. CleanLock вернул управление."
        }
    }
}

extension AppStrings {
    enum Key {
        case notGranted
        case granted
        case requiresRestart
        case requiresManualCheck
        case permissionIssueAccessibility
        case permissionIssueInputMonitoring
        case permissionIssueGeneric
        case autoUnlockFiveMinutes
        case autoUnlockTenMinutes
        case autoUnlockTwentyMinutes
        case displayScopeAllDisplays
        case displayScopeMainDisplay
        case cleaningModeEnabled
        case startCleaningMode
        case settings
        case quit
        case settingsWindowTitle
        case welcomeSubtitle
        case welcomeBody
        case continueButton
        case permissionsTitle
        case permissionsDescription
        case accessibilityTitle
        case accessibilityDescription
        case inputMonitoringTitle
        case inputMonitoringDescription
        case permissionsPrivacyNote
        case backButton
        case unlockTestTitle
        case unlockTestDescription
        case leftCommand
        case rightCommand
        case unlockTestFootnote
        case completedTitle
        case completedDescription
        case doneButton
        case openButton
        case overlayTitle
        case overlayInputBlocked
        case overlayExitInstruction
        case settingsTitle
        case launchAtLogin
        case language
        case autoUnlock
        case autoUnlockSubtitle
        case displays
        case displaysSubtitle
        case overlayNoScreens
        case inputBlockerFailed
        case eventTapStopped
        case cleaningModeNotStarted
        case cleaningModeDisabled
        case displayConfigurationChanged
    }
}

extension Notification.Name {
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")
}
