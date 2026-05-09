import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case en
    case pl

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .en: return String(localized: "English")
        case .pl: return String(localized: "Polish")
        }
    }

    /// Apply the selected language by writing to the AppleLanguages UserDefault.
    /// iOS reads this on the next launch; a restart is required for the change
    /// to take effect throughout the app.
    func apply() {
        UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
    }
}
