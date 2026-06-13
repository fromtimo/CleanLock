import Foundation

enum DisplayScope: String, CaseIterable, Identifiable {
    case allDisplays
    case mainDisplay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allDisplays:
            return "Все экраны"
        case .mainDisplay:
            return "Только главный экран"
        }
    }
}
