import Foundation
import ServiceManagement

@MainActor
final class PreferencesStore: ObservableObject {
    static let shared = PreferencesStore()

    enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let autoUnlockDuration = "cleaningModeAutoUnlockDuration"
        static let displayScope = "cleaningModeDisplayScope"
        static let appLanguage = "appLanguage"
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }

    @Published var autoUnlockDuration: AutoUnlockDuration {
        didSet {
            defaults.set(autoUnlockDuration.rawValue, forKey: Keys.autoUnlockDuration)
        }
    }

    @Published var displayScope: DisplayScope {
        didSet {
            defaults.set(displayScope.rawValue, forKey: Keys.displayScope)
        }
    }

    @Published var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            NotificationCenter.default.post(name: .appLanguageDidChange, object: self)
        }
    }

    @Published private(set) var launchAtLoginEnabled: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)

        let durationRawValue = defaults.string(forKey: Keys.autoUnlockDuration)
        self.autoUnlockDuration = durationRawValue
            .flatMap(AutoUnlockDuration.init(rawValue:)) ?? .tenMinutes

        let displayScopeRawValue = defaults.string(forKey: Keys.displayScope)
        self.displayScope = displayScopeRawValue
            .flatMap(DisplayScope.init(rawValue:)) ?? .allDisplays

        let languageRawValue = defaults.string(forKey: Keys.appLanguage)
        self.appLanguage = languageRawValue
            .flatMap(AppLanguage.init(rawValue:)) ?? .defaultForSystem

        self.launchAtLoginEnabled = Self.isLaunchAtLoginEnabled
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = Self.isLaunchAtLoginEnabled
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        guard isEnabled != launchAtLoginEnabled else { return }

        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Failed to update launch at login: \(error.localizedDescription)")
        }

        refreshLaunchAtLoginStatus()
    }

    private static var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
