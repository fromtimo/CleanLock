import AppKit
import SwiftUI

@MainActor
struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var permissions = PermissionManager.shared
    @StateObject private var unlockTest = CommandUnlockTestModel()
    @State private var step: OnboardingStep
    @State private var navigationDirection: NavigationDirection = .forward

    let onComplete: () -> Void

    init(initialStep: OnboardingStep = .welcome, onComplete: @escaping () -> Void = {}) {
        self._step = State(initialValue: initialStep)
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            WindowGlassBackground()
                .ignoresSafeArea()

            ZStack {
                content
                    .id(step)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(stepTransition)
            }
            .padding(.horizontal, 36)
            .padding(.top, 34)
            .padding(.bottom, 28)
            .clipped()
        }
        .onAppear {
            permissions.checkPermissions()
        }
        .onDisappear {
            unlockTest.stop()
        }
        .task(id: step) {
            await refreshPermissionsWhileNeeded()
        }
        .onChange(of: step) { newStep in
            handleStepChange(newStep)
        }
        .onChange(of: unlockTest.isCompleted) { isCompleted in
            guard isCompleted else { return }
            advance(to: .completed)
        }
    }

    private var stepTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }

        return .asymmetric(
            insertion: .move(edge: navigationDirection.insertionEdge).combined(with: .opacity),
            removal: .move(edge: navigationDirection.removalEdge).combined(with: .opacity)
        )
    }

    private var stepAnimation: Animation? {
        reduceMotion
            ? .easeInOut(duration: 0.16)
            : .spring(response: 0.35, dampingFraction: 0.86, blendDuration: 0.08)
    }

    private func advance(to nextStep: OnboardingStep) {
        navigate(to: nextStep, direction: .forward)
    }

    private func retreat(to previousStep: OnboardingStep) {
        navigate(to: previousStep, direction: .backward)
    }

    private func navigate(to nextStep: OnboardingStep, direction: NavigationDirection) {
        navigationDirection = direction

        withAnimation(stepAnimation) {
            step = nextStep
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            welcomeStep
        case .permissions:
            permissionsStep
        case .unlockTest:
            unlockTestStep
        case .completed:
            completedStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text("CleanLock")
                    .font(.system(size: 30, weight: .semibold))

                Text("Безопасно чисти клавиатуру и трекпад MacBook без случайных нажатий.")
                    .font(.title3)
                    .multilineTextAlignment(.center)

                Text("Утилита временно блокирует клавиатуру и клики по трекпаду, затемняет экран и показывает понятный способ выхода из режима очистки.\n\nCleanLock не записывает нажатия клавиш, не использует интернет и не собирает аналитику.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 460)
            .offset(y: -18)

            Spacer()

            HStack {
                Spacer()

                Button("Продолжить") {
                    advance(to: .permissions)
                }
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Нужны разрешения macOS")
                .font(.system(size: 24, weight: .semibold))

            Text("Чтобы блокировать случайные нажатия и определять сочетание для выхода из режима очистки, CleanLock нужны системные разрешения.")
                .foregroundStyle(.secondary)

            PermissionRow(
                title: "Универсальный доступ",
                description: "Позволяет CleanLock блокировать события клавиатуры и трекпада во время режима очистки.",
                status: permissions.accessibilityStatus,
                action: {
                    permissions.openAccessibilitySettings()
                }
            )

            PermissionRow(
                title: "Мониторинг ввода",
                description: "Позволяет CleanLock определять удержание двух клавиш Command для выхода из режима очистки.",
                status: permissions.inputMonitoringStatus,
                action: {
                    permissions.openInputMonitoringSettings()
                }
            )

            Text("Нажатия не сохраняются и никуда не отправляются. Разрешения нужны только для работы режима блокировки.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Button("Назад") {
                    retreat(to: .welcome)
                }
                .controlSize(.large)

                Spacer()

                Button("Продолжить") {
                    advance(to: .unlockTest)
                }
                .disabled(!permissions.canContinuePastPermissionStep)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var unlockTestStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                Text("Проверь разблокировку")
                    .font(.system(size: 26, weight: .semibold))

                Text("Удерживай левую и правую клавиши Command в течение 3 секунд.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 32) {
                    OnboardingCommandKeyView(
                        title: "Левый ⌘",
                        isActive: unlockTest.commandKeyState.isLeftCommandPressed,
                        progress: unlockTest.progressForVisibleRings
                    )

                    OnboardingCommandKeyView(
                        title: "Правый ⌘",
                        isActive: unlockTest.commandKeyState.isRightCommandPressed,
                        progress: unlockTest.progressForVisibleRings
                    )
                }
                .padding(.top, 12)

                Text("Для выхода нужны левая и правая Command. Если на внешней клавиатуре нет правой Command или сочетание не сработает, режим автоматически отключится по страховочному таймеру.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .frame(maxWidth: 500)
            .offset(y: -26)

            Spacer()

            HStack {
                Button("Назад") {
                    retreat(to: .permissions)
                }
                .controlSize(.large)

                Spacer()
            }
        }
    }

    private var completedStep: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                Text("Настройка завершена")
                    .font(.system(size: 28, weight: .semibold))

                Text("CleanLock готов к использованию. Включить режим очистки можно через иконку в меню-баре.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 500)
            .offset(y: -24)

            Spacer()

            Button("Готово") {
                PreferencesStore.shared.hasCompletedOnboarding = true
                onComplete()
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func handleStepChange(_ newStep: OnboardingStep) {
        switch newStep {
        case .unlockTest:
            unlockTest.start()
        case .completed:
            unlockTest.stop()
        case .welcome, .permissions:
            unlockTest.stop()
        }
    }

    private func refreshPermissionsWhileNeeded() async {
        guard step == .permissions else { return }

        while !Task.isCancelled {
            permissions.checkPermissions()

            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }
        }
    }
}

private enum NavigationDirection {
    case forward
    case backward

    var insertionEdge: Edge {
        switch self {
        case .forward:
            return .trailing
        case .backward:
            return .leading
        }
    }

    var removalEdge: Edge {
        switch self {
        case .forward:
            return .leading
        case .backward:
            return .trailing
        }
    }
}

struct WindowGlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
    }
}

struct WindowTitleHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        hideTitleWhenWindowIsAvailable(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        hideTitleWhenWindowIsAvailable(from: nsView)
    }

    private func hideTitleWhenWindowIsAvailable(from view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }

            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let description: String
    let status: PermissionState
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(symbolColor)
                .frame(width: 22, height: 22, alignment: .center)
                .padding(.top, 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)

                    Spacer()

                    Text(status.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if status != .granted {
                        Button("Открыть") {
                            action()
                        }
                        .controlSize(.small)
                    }
                }

                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var symbolName: String {
        switch status {
        case .granted:
            return "checkmark.circle.fill"
        case .requiresRestart:
            return "exclamationmark.triangle"
        case .notGranted, .requiresManualCheck:
            return "exclamationmark.circle"
        }
    }

    private var symbolColor: Color {
        switch status {
        case .granted:
            return .green
        case .requiresRestart:
            return .orange
        case .notGranted, .requiresManualCheck:
            return .secondary
        }
    }
}

private struct OnboardingCommandKeyView: View {
    let title: String
    let isActive: Bool
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(Color.primary.opacity(0.72), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 24, height: 24)
            .opacity(progress > 0 ? 1 : 0)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
                .frame(width: 112, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(isActive ? 0.12 : 0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(isActive ? 0.34 : 0.18), lineWidth: 1)
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

private final class CommandUnlockTestModel: ObservableObject {
    @Published private(set) var commandKeyState: CommandKeyState = .inactive
    @Published private(set) var isCompleted = false

    var progressForVisibleRings: Double {
        commandKeyState.isLeftCommandPressed && commandKeyState.isRightCommandPressed
            ? commandKeyState.progress
            : 0
    }

    private static let leftCommandKeyCode: UInt16 = 55
    private static let rightCommandKeyCode: UInt16 = 54
    private static let leftCommandMask: UInt = 0x00000008
    private static let rightCommandMask: UInt = 0x00000010
    private static let sideCommandMask = leftCommandMask | rightCommandMask

    private let unlockDuration: TimeInterval = 3
    private var eventMonitor: Any?
    private var progressTimer: Timer?
    private var holdStartedAt: Date?
    private var isLeftCommandPressed = false
    private var isRightCommandPressed = false

    deinit {
        stop()
    }

    func start() {
        stop()
        reset()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    func stop() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        stopProgressTimer(resetProgress: true)
        isLeftCommandPressed = false
        isRightCommandPressed = false
        commandKeyState = .inactive
    }

    private func reset() {
        isCompleted = false
        isLeftCommandPressed = false
        isRightCommandPressed = false
        commandKeyState = .inactive
        stopProgressTimer(resetProgress: true)
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard !isCompleted else { return }

        updateCommandState(from: event)

        let bothPressed = isLeftCommandPressed && isRightCommandPressed
        if bothPressed {
            startProgressTimerIfNeeded()
        } else {
            stopProgressTimer(resetProgress: true)
        }

        publishCommandState()
    }

    private func updateCommandState(from event: NSEvent) {
        let rawFlags = event.modifierFlags.rawValue
        let hasSideSpecificFlags = (rawFlags & Self.sideCommandMask) != 0

        if hasSideSpecificFlags || !event.modifierFlags.contains(.command) {
            isLeftCommandPressed = (rawFlags & Self.leftCommandMask) != 0
            isRightCommandPressed = (rawFlags & Self.rightCommandMask) != 0
            return
        }

        switch event.keyCode {
        case Self.leftCommandKeyCode:
            isLeftCommandPressed = event.modifierFlags.contains(.command)
        case Self.rightCommandKeyCode:
            isRightCommandPressed = event.modifierFlags.contains(.command)
        default:
            break
        }
    }

    private func startProgressTimerIfNeeded() {
        guard progressTimer == nil else { return }

        holdStartedAt = Date()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
        updateProgress()
    }

    private func stopProgressTimer(resetProgress: Bool) {
        progressTimer?.invalidate()
        progressTimer = nil
        holdStartedAt = nil

        if resetProgress {
            commandKeyState = CommandKeyState(
                isLeftCommandPressed: isLeftCommandPressed,
                isRightCommandPressed: isRightCommandPressed,
                progress: 0
            )
        }
    }

    private func updateProgress() {
        guard let holdStartedAt else { return }

        let elapsed = Date().timeIntervalSince(holdStartedAt)
        let progress = min(max(elapsed / unlockDuration, 0), 1)

        commandKeyState = CommandKeyState(
            isLeftCommandPressed: isLeftCommandPressed,
            isRightCommandPressed: isRightCommandPressed,
            progress: progress
        )

        if progress >= 1 {
            isCompleted = true
            stopProgressTimer(resetProgress: false)
        }
    }

    private func publishCommandState() {
        commandKeyState = CommandKeyState(
            isLeftCommandPressed: isLeftCommandPressed,
            isRightCommandPressed: isRightCommandPressed,
            progress: commandKeyState.progress
        )
    }
}
