import Foundation

enum CardSortOrder: String, CaseIterable, Identifiable {
    case alphabetical = "Alphabetical"
    case dateAdded    = "Date Added"
    case lastUsed     = "Last Used"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alphabetical: return String(localized: "Alphabetical")
        case .dateAdded:    return String(localized: "Date Added")
        case .lastUsed:     return String(localized: "Last Used")
        }
    }
}
