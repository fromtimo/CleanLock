import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject private var preferences = PreferencesStore.shared

    var body: some View {
        ZStack {
            WindowGlassBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text(text(.settingsTitle))
                    .font(.system(size: 24, weight: .semibold))

                VStack(spacing: 10) {
                    SettingsIslandRow(title: text(.launchAtLogin)) {
                        Toggle("", isOn: launchAtLoginBinding)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    SettingsIslandRow(title: text(.language)) {
                        Picker(text(.language), selection: $preferences.appLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.title).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 128, alignment: .trailing)
                    }

                    SettingsIslandRow(
                        title: text(.autoUnlock),
                        subtitle: text(.autoUnlockSubtitle)
                    ) {
                        Picker(text(.autoUnlock), selection: $preferences.autoUnlockDuration) {
                            ForEach(AutoUnlockDuration.allCases) { duration in
                                Text(duration.title(language: preferences.appLanguage)).tag(duration)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 128, alignment: .trailing)
                    }

                    SettingsIslandRow(
                        title: text(.displays),
                        subtitle: text(.displaysSubtitle)
                    ) {
                        Picker(text(.displays), selection: $preferences.displayScope) {
                            ForEach(DisplayScope.allCases) { scope in
                                Text(scope.title(language: preferences.appLanguage)).tag(scope)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 176, alignment: .trailing)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 6) {
                    Text(appVersionText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(24)
        }
        .frame(width: 520, height: 430)
        .background(WindowTitleHider(extendsContentIntoTitlebar: true))
        .onAppear {
            preferences.refreshLaunchAtLoginStatus()
        }
    }

    private func text(_ key: AppStrings.Key) -> String {
        AppStrings.text(key, language: preferences.appLanguage)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { preferences.launchAtLoginEnabled },
            set: { preferences.setLaunchAtLoginEnabled($0) }
        )
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.2"
        return "v\(version)"
    }
}

private struct SettingsIslandRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)

            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
