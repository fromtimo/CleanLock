import SwiftUI

@MainActor
struct CleaningOverlayView: View {
    @ObservedObject var state: OverlayState
    @ObservedObject private var preferences = PreferencesStore.shared

    private var commandKeyState: CommandKeyState {
        state.commandKeyState
    }

    private var bothCommandsPressed: Bool {
        commandKeyState.isLeftCommandPressed && commandKeyState.isRightCommandPressed
    }

    private var visibleProgress: Double {
        state.isUnlockCompleted || bothCommandsPressed
            ? commandKeyState.progress
            : 0
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(state.backgroundOpacity)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.86))

                Text(text(.overlayTitle))
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.86))

                VStack(spacing: 4) {
                    Text(text(.overlayInputBlocked))
                    Text(text(.overlayExitInstruction))
                }
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.58))
                .lineSpacing(4)

                UnlockProgressIndicator(
                    progress: visibleProgress,
                    isCompleted: state.isUnlockCompleted
                )
                .padding(.top, 8)
                .padding(.bottom, -2)

                HStack(spacing: 32) {
                    CommandKeyView(
                        title: text(.leftCommand),
                        isActive: commandKeyState.isLeftCommandPressed
                    )

                    CommandKeyView(
                        title: text(.rightCommand),
                        isActive: commandKeyState.isRightCommandPressed
                    )
                }
            }
            .padding(32)
            .opacity(state.showsContent ? 1 : 0)
            .offset(y: state.contentYOffset)

            VStack {
                Spacer()

                if let remainingSeconds = state.autoUnlockRemainingSeconds {
                    AutoUnlockCountdownView(
                        prefix: text(.autoUnlockCountdownPrefix),
                        remainingSeconds: remainingSeconds
                    )
                    .opacity(state.showsContent ? 1 : 0)
                    .padding(.bottom, 28)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func text(_ key: AppStrings.Key) -> String {
        AppStrings.text(key, language: preferences.appLanguage)
    }
}

private struct CommandKeyView: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Color.white.opacity(isActive ? 0.86 : 0.64))
            .frame(width: 104, height: 42)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isActive ? 0.16 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(isActive ? 0.38 : 0.22), lineWidth: 1)
            )
    }
}

struct UnlockProgressIndicator: View {
    let progress: Double
    let isCompleted: Bool
    var tint: Color = .white

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), lineWidth: 2)
                .opacity(isCompleted || progress > 0 ? 1 : 0.18)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint.opacity(0.78), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(isCompleted ? 0 : 1)

            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint.opacity(0.88))
                .scaleEffect(isCompleted ? 1 : 0.7)
                .opacity(isCompleted ? 1 : 0)
        }
        .frame(width: 24, height: 24)
        .animation(.easeInOut(duration: 0.18), value: progress)
        .animation(.spring(response: 0.3, dampingFraction: 0.78), value: isCompleted)
    }
}

private struct AutoUnlockCountdownView: View {
    let prefix: String
    let remainingSeconds: Int

    var body: some View {
        HStack(spacing: 0) {
            Text(prefix)
            Text(" ")
            CountdownText(remainingSeconds: remainingSeconds)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.white.opacity(0.46))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
    }
}

private struct CountdownText: View {
    let remainingSeconds: Int

    var body: some View {
        HStack(spacing: 0) {
            AnimatedCountdownCharacter(character: minuteTensCharacter)
            AnimatedCountdownCharacter(character: minuteOnesCharacter)
            Text(":")
                .frame(width: characterWidth)
            AnimatedCountdownCharacter(character: secondsTensCharacter)
            AnimatedCountdownCharacter(character: secondsOnesCharacter)
        }
        .monospacedDigit()
    }

    private var clampedSeconds: Int {
        max(remainingSeconds, 0)
    }

    private var minutes: Int {
        clampedSeconds / 60
    }

    private var seconds: Int {
        clampedSeconds % 60
    }

    private var minuteTensCharacter: Character {
        Character(String((minutes / 10) % 10))
    }

    private var minuteOnesCharacter: Character {
        Character(String(minutes % 10))
    }

    private var secondsTensCharacter: Character {
        Character(String(seconds / 10))
    }

    private var secondsOnesCharacter: Character {
        Character(String(seconds % 10))
    }
}

private struct AnimatedCountdownCharacter: View {
    let character: Character

    @State private var displayedCharacter: Character
    @State private var outgoingCharacter: Character?
    @State private var animationPhase: CGFloat = 1
    @State private var animationID = 0

    private let animationDuration: TimeInterval = 0.24

    init(character: Character) {
        self.character = character
        self._displayedCharacter = State(initialValue: character)
    }

    var body: some View {
        ZStack {
            Text("8")
                .hidden()

            if let outgoingCharacter {
                characterText(outgoingCharacter)
                    .opacity(1 - animationPhase)
                    .offset(y: 8 * animationPhase)
                    .blur(radius: 4 * animationPhase)
            }

            characterText(displayedCharacter)
                .opacity(incomingOpacity)
                .offset(y: incomingYOffset)
                .blur(radius: incomingBlurRadius)
        }
        .frame(width: characterWidth)
        .clipped()
        .onChange(of: character) { newValue in
            updateDisplayedCharacter(newValue)
        }
    }

    private func characterText(_ character: Character) -> some View {
        Text(String(character))
    }

    private func updateDisplayedCharacter(_ newValue: Character) {
        guard newValue != displayedCharacter else { return }

        let oldValue = displayedCharacter

        animationID += 1
        let currentAnimationID = animationID

        outgoingCharacter = oldValue
        displayedCharacter = newValue

        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            animationPhase = 0
        }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: animationDuration)) {
                animationPhase = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + 0.03) {
            guard animationID == currentAnimationID else { return }
            outgoingCharacter = nil
            animationPhase = 1
        }
    }

    private var incomingOpacity: Double {
        outgoingCharacter == nil ? 1 : animationPhase
    }

    private var incomingYOffset: CGFloat {
        outgoingCharacter == nil ? 0 : -8 * (1 - animationPhase)
    }

    private var incomingBlurRadius: CGFloat {
        outgoingCharacter == nil ? 0 : 4 * (1 - animationPhase)
    }
}

private let characterWidth: CGFloat = 8
