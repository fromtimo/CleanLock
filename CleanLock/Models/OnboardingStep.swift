import Foundation

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case permissions
    case unlockTest
    case completed

    var id: Int { rawValue }
}
