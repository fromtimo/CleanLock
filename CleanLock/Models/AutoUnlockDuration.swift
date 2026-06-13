import Foundation

enum AutoUnlockDuration: String, CaseIterable, Identifiable {
    case fiveMinutes
    case tenMinutes
    case twentyMinutes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fiveMinutes:
            return "5 минут"
        case .tenMinutes:
            return "10 минут"
        case .twentyMinutes:
            return "20 минут"
        }
    }

    var timeInterval: TimeInterval {
        switch self {
        case .fiveMinutes:
            return 5 * 60
        case .tenMinutes:
            return 10 * 60
        case .twentyMinutes:
            return 20 * 60
        }
    }
}
