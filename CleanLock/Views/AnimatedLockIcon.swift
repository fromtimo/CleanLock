import AppKit
import SwiftUI

enum AnimatedLockIconState: Equatable {
    case unlocked
    case locking
    case locked
    case unlocking
}

enum AnimatedLockIconTiming {
    static let lockingDuration: TimeInterval = 0.93
    static let unlockingDuration: TimeInterval = 0.80

    static let lockingLiftDuration: TimeInterval = 0.16
    static let lockingRotateDuration: TimeInterval = 0.28
    static let lockingDropDuration: TimeInterval = 0.18
    static let lockingOvershootDuration: TimeInterval = 0.09
    static let lockingSettleDuration: TimeInterval = 0.14
    static let lockingReturnDuration: TimeInterval = 0.08

    static let unlockingPressDuration: TimeInterval = 0.14
    static let unlockingLiftDuration: TimeInterval = 0.22
    static let unlockingRotateDuration: TimeInterval = 0.28
    static let unlockingSettleDuration: TimeInterval = 0.16
}

struct AnimatedLockIcon: View {
    let state: AnimatedLockIconState

    @SwiftUI.State private var animationTask: Task<Void, Never>?
    @SwiftUI.State private var shackleRotationDegrees: Double = 180
    @SwiftUI.State private var shackleYOffset: CGFloat = -5
    @SwiftUI.State private var bodyYOffset: CGFloat = 0
    @SwiftUI.State private var iconScale: CGFloat = 1

    private let tint = Color.white

    var body: some View {
        ZStack {
            ZStack {
                FixedShackleLeg(tint: tint)

                RotatingShacklePart(
                    tint: tint,
                    rotationDegrees: shackleRotationDegrees
                )
            }
                .offset(y: shackleYOffset)
                .zIndex(0)

            LockBodyLayer(tint: tint)
                .offset(y: bodyYOffset)
                .zIndex(1)
        }
        .frame(width: 44, height: 44)
        .compositingGroup()
        .opacity(0.86)
        .scaleEffect(iconScale)
        .onAppear {
            applyFinalState(for: state, animated: false)
        }
        .onChange(of: state) { newState in
            updateState(newState)
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private func updateState(_ newState: AnimatedLockIconState) {
        animationTask?.cancel()

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            applyFinalState(for: newState, animated: false)
            return
        }

        switch newState {
        case .unlocked:
            applyUnlocked(animated: true)
        case .locking:
            animationTask = Task { @MainActor in
                await runLockingAnimation()
            }
        case .locked:
            applyLocked(animated: true)
        case .unlocking:
            animationTask = Task { @MainActor in
                await runUnlockingAnimation()
            }
        }
    }

    private func runLockingAnimation() async {
        applyUnlocked(animated: false)

        withAnimation(.easeOut(duration: AnimatedLockIconTiming.lockingLiftDuration)) {
            shackleYOffset = -8
        }
        await sleep(seconds: AnimatedLockIconTiming.lockingLiftDuration)

        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: AnimatedLockIconTiming.lockingRotateDuration)) {
            shackleRotationDegrees = 0
        }
        await sleep(seconds: AnimatedLockIconTiming.lockingRotateDuration)

        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: AnimatedLockIconTiming.lockingDropDuration)) {
            shackleYOffset = 0
        }
        await sleep(seconds: AnimatedLockIconTiming.lockingDropDuration)

        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: AnimatedLockIconTiming.lockingOvershootDuration)) {
            shackleYOffset = LockIconMetrics.lockInOvershootYOffset
        }
        await sleep(seconds: AnimatedLockIconTiming.lockingOvershootDuration)

        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86, blendDuration: 0)) {
            shackleYOffset = 0
        }
        await sleep(seconds: AnimatedLockIconTiming.lockingSettleDuration)

        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: AnimatedLockIconTiming.lockingReturnDuration)) {
            bodyYOffset = 0
            iconScale = 1
        }
    }

    private func runUnlockingAnimation() async {
        applyLocked(animated: false)

        withAnimation(.easeInOut(duration: AnimatedLockIconTiming.unlockingPressDuration)) {
            shackleYOffset = LockIconMetrics.lockInOvershootYOffset
        }
        await sleep(seconds: AnimatedLockIconTiming.unlockingPressDuration)

        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: AnimatedLockIconTiming.unlockingLiftDuration)) {
            shackleYOffset = -8
            bodyYOffset = 0
            iconScale = 1
        }
        await sleep(seconds: AnimatedLockIconTiming.unlockingLiftDuration)

        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: AnimatedLockIconTiming.unlockingRotateDuration)) {
            shackleRotationDegrees = 180
        }
        await sleep(seconds: AnimatedLockIconTiming.unlockingRotateDuration)

        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: AnimatedLockIconTiming.unlockingSettleDuration)) {
            shackleYOffset = -5
        }
    }

    private func applyFinalState(for state: AnimatedLockIconState, animated: Bool) {
        switch state {
        case .unlocked, .unlocking:
            applyUnlocked(animated: animated)
        case .locking, .locked:
            applyLocked(animated: animated)
        }
    }

    private func applyUnlocked(animated: Bool) {
        apply(animated: animated, duration: 0.16) {
            shackleRotationDegrees = 180
            shackleYOffset = -5
            bodyYOffset = 0
            iconScale = 1
        }
    }

    private func applyLocked(animated: Bool) {
        apply(animated: animated, duration: 0.16) {
            shackleRotationDegrees = 0
            shackleYOffset = 0
            bodyYOffset = 0
            iconScale = 1
        }
    }

    private func apply(animated: Bool, duration: TimeInterval, changes: @escaping () -> Void) {
        if animated {
            withAnimation(.easeOut(duration: duration), changes)
        } else {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction, changes)
        }
    }

    private func sleep(seconds: TimeInterval) async {
        let nanoseconds = UInt64(max(seconds, 0) * 1_000_000_000)
        guard nanoseconds > 0 else { return }
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

private enum LockIconMetrics {
    static let canvasSize: CGFloat = 44
    static let bodyWidth: CGFloat = 32
    static let bodyHeight: CGFloat = 23
    static let bodyCenter = CGPoint(x: 22, y: 31)
    static let bodyCornerRadius: CGFloat = 6.4
    static let bodyTopY: CGFloat = bodyCenter.y - bodyHeight / 2

    static let strokeWidth: CGFloat = 4.7
    static let fixedLegX: CGFloat = 31
    static let freeLegX: CGFloat = 13
    static let shackleShoulderY: CGFloat = 13.3
    static let shackleRadius: CGFloat = (fixedLegX - freeLegX) / 2
    static let shackleTopY: CGFloat = shackleShoulderY - shackleRadius
    static let shackleBottomY: CGFloat = bodyTopY + 1
    static let fixedLegBottomY: CGFloat = bodyTopY + 12
    static let lockInOvershootYOffset: CGFloat = 3.5
}

private struct FixedShackleLeg: View {
    let tint: Color

    var body: some View {
        FixedShackleLegShape()
            .stroke(
                tint,
                style: StrokeStyle(lineWidth: LockIconMetrics.strokeWidth, lineCap: .round, lineJoin: .round)
            )
            .frame(width: LockIconMetrics.canvasSize, height: LockIconMetrics.canvasSize)
    }
}

private struct RotatingShacklePart: View {
    let tint: Color
    let rotationDegrees: Double

    var body: some View {
        RotatingShacklePartShape(rotationDegrees: rotationDegrees)
            .stroke(
                tint,
                style: StrokeStyle(lineWidth: LockIconMetrics.strokeWidth, lineCap: .round, lineJoin: .round)
            )
            .frame(width: LockIconMetrics.canvasSize, height: LockIconMetrics.canvasSize)
    }
}

private struct LockBodyLayer: View {
    let tint: Color

    var body: some View {
        ZStack {
            LockBodyShape()
                .fill(tint)
        }
        .frame(width: LockIconMetrics.canvasSize, height: LockIconMetrics.canvasSize)
    }
}

private struct LockBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = LockIconMetrics.bodyWidth
        let height = LockIconMetrics.bodyHeight
        let left = LockIconMetrics.bodyCenter.x - width / 2
        let right = LockIconMetrics.bodyCenter.x + width / 2
        let top = LockIconMetrics.bodyCenter.y - height / 2
        let bottom = LockIconMetrics.bodyCenter.y + height / 2
        let radius = LockIconMetrics.bodyCornerRadius

        var path = Path()
        path.move(to: CGPoint(x: left + radius, y: top))
        path.addLine(to: CGPoint(x: right - radius, y: top))
        path.addQuadCurve(
            to: CGPoint(x: right, y: top + radius),
            control: CGPoint(x: right, y: top)
        )
        path.addLine(to: CGPoint(x: right, y: bottom - radius))
        path.addQuadCurve(
            to: CGPoint(x: right - radius, y: bottom),
            control: CGPoint(x: right, y: bottom)
        )
        path.addLine(to: CGPoint(x: left + radius, y: bottom))
        path.addQuadCurve(
            to: CGPoint(x: left, y: bottom - radius),
            control: CGPoint(x: left, y: bottom)
        )
        path.addLine(to: CGPoint(x: left, y: top + radius))
        path.addQuadCurve(
            to: CGPoint(x: left + radius, y: top),
            control: CGPoint(x: left, y: top)
        )

        return path
    }
}

private struct FixedShackleLegShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: LockIconMetrics.fixedLegX, y: LockIconMetrics.fixedLegBottomY))
        path.addLine(to: CGPoint(x: LockIconMetrics.fixedLegX, y: LockIconMetrics.shackleShoulderY))

        return path
    }
}

private struct RotatingShacklePartShape: Shape {
    var rotationDegrees: Double

    var animatableData: Double {
        get { rotationDegrees }
        set { rotationDegrees = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let centerX = (LockIconMetrics.fixedLegX + LockIconMetrics.freeLegX) / 2
        let centerY = LockIconMetrics.shackleShoulderY
        let radius = LockIconMetrics.shackleRadius
        let kappa = 0.5522847498
        let topPoint = CGPoint(x: centerX, y: LockIconMetrics.shackleTopY)
        let fixedShoulder = CGPoint(x: LockIconMetrics.fixedLegX, y: LockIconMetrics.shackleShoulderY)
        let freeShoulder = CGPoint(x: LockIconMetrics.freeLegX, y: LockIconMetrics.shackleShoulderY)

        path.move(to: rotated(fixedShoulder))
        path.addCurve(
            to: rotated(topPoint),
            control1: rotated(CGPoint(
                x: LockIconMetrics.fixedLegX,
                y: centerY - kappa * radius
            )),
            control2: rotated(CGPoint(
                x: centerX + kappa * radius,
                y: LockIconMetrics.shackleTopY
            ))
        )
        path.addCurve(
            to: rotated(freeShoulder),
            control1: rotated(CGPoint(
                x: centerX - kappa * radius,
                y: LockIconMetrics.shackleTopY
            )),
            control2: rotated(CGPoint(
                x: LockIconMetrics.freeLegX,
                y: centerY - kappa * radius
            ))
        )
        path.addLine(to: rotated(CGPoint(
            x: LockIconMetrics.freeLegX,
            y: LockIconMetrics.shackleBottomY
        )))

        return path
    }

    private func rotated(_ point: CGPoint) -> CGPoint {
        let radians = rotationDegrees * .pi / 180
        let pivotX = LockIconMetrics.fixedLegX
        let projectedX = pivotX + cos(radians) * (point.x - pivotX)

        return CGPoint(x: projectedX, y: point.y)
    }
}
