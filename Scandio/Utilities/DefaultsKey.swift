import Foundation

/// Centralized string keys used by both `@AppStorage` and direct
/// `UserDefaults.standard` reads. Prevents drift between the SwiftUI view
/// and the services that read the same defaults.
enum DefaultsKey {
    static let cardSortOrder = "cardSortOrder"
    static let brightnessEnabled = "brightnessEnabled"
    static let brightnessLevel = "brightnessLevel"
    static let appTheme = "appTheme"
    static let appLanguage = "appLanguage"
    static let duplicatePolicy = "duplicatePolicy"
}
