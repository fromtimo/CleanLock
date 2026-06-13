import Foundation

enum DisplayScope: String, CaseIterable, Identifiable {
    case allDisplays
    case mainDisplay

    var id: String { rawValue }

    var title: String {
        title(language: .current)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .allDisplays:
            return AppStrings.text(.displayScopeAllDisplays, language: language)
        case .mainDisplay:
            return AppStrings.text(.displayScopeMainDisplay, language: language)
        }
    }
}
