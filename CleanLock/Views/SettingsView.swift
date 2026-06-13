import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject private var preferences = PreferencesStore.shared

    var body: some View {
        ZStack {
            WindowGlassBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Настройки")
                    .font(.system(size: 24, weight: .semibold))

                VStack(spacing: 10) {
                    SettingsIslandRow(title: "Запускать при входе") {
                        Toggle("", isOn: launchAtLoginBinding)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }

                    SettingsIslandRow(
                        title: "Автоотключение",
                        subtitle: "Страховочный таймер для выхода из режима очистки."
                    ) {
                        Picker("Автоотключение", selection: $preferences.autoUnlockDuration) {
                            ForEach(AutoUnlockDuration.allCases) { duration in
                                Text(duration.title).tag(duration)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 128, alignment: .trailing)
                    }

                    SettingsIslandRow(
                        title: "Экраны",
                        subtitle: "Какие экраны затемнять во время режима очистки."
                    ) {
                        Picker("Экраны", selection: $preferences.displayScope) {
                            ForEach(DisplayScope.allCases) { scope in
                                Text(scope.title).tag(scope)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 176, alignment: .trailing)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(width: 520, height: 380)
        .background(WindowTitleHider())
        .onAppear {
            preferences.refreshLaunchAtLoginStatus()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { preferences.launchAtLoginEnabled },
            set: { preferences.setLaunchAtLoginEnabled($0) }
        )
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
