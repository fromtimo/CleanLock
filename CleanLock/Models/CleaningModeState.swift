import Foundation

enum CleaningModeState: Equatable {
    case inactive
    case starting
    case active
    case unlocking(progress: Double)
    case stopping

    var isActive: Bool {
        switch self {
        case .inactive:
            return false
        case .starting, .active, .unlocking, .stopping:
            return true
        }
    }
}
