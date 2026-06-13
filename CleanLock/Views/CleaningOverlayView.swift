import SwiftUI

@MainActor
struct CleaningOverlayView: View {
    @ObservedObject var state: OverlayState

    private var commandKeyState: CommandKeyState {
        state.commandKeyState
    }

    private var bothCommandsPressed: Bool {
        commandKeyState.isLeftCommandPressed && commandKeyState.isRightCommandPressed
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

                Text("Режим очистки")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.86))

                VStack(spacing: 4) {
                    Text("Клавиатура и клики заблокированы.")
                    Text("Для выхода удерживай левую и правую Command 3 секунды.")
                }
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.58))
                .lineSpacing(4)

                HStack(spacing: 32) {
                    CommandKeyView(
                        title: "Левый ⌘",
                        isActive: commandKeyState.isLeftCommandPressed,
                        progress: bothCommandsPressed ? commandKeyState.progress : 0
                    )

                    CommandKeyView(
                        title: "Правый ⌘",
                        isActive: commandKeyState.isRightCommandPressed,
                        progress: bothCommandsPressed ? commandKeyState.progress : 0
                    )
                }
                .padding(.top, 10)
            }
            .padding(32)
            .opacity(state.showsContent ? 1 : 0)
            .offset(y: state.contentYOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CommandKeyView: View {
    let title: String
    let isActive: Bool
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(Color.white.opacity(0.78), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 22, height: 22)
            .opacity(progress > 0 ? 1 : 0)

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
}
