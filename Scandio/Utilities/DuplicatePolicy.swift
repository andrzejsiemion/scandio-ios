import Foundation

/// User-facing policy for what to do when an import contains a card whose
/// (name, cardNumber) already exists locally. Stored as `@AppStorage`.
enum DuplicatePolicy: String, CaseIterable, Identifiable {
    case ask
    case skip
    case merge
    case duplicate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ask:       return String(localized: "Ask")
        case .skip:      return String(localized: "Skip")
        case .merge:     return String(localized: "Merge")
        case .duplicate: return String(localized: "Add as new")
        }
    }

    /// Returns nil for `.ask` — the caller must resolve via a prompt.
    var resolved: ResolvedDuplicatePolicy? {
        switch self {
        case .ask:       return nil
        case .skip:      return .skip
        case .merge:     return .merge
        case .duplicate: return .duplicate
        }
    }
}

/// Concrete action used by `BackupManager.apply`. Excludes `.ask`.
enum ResolvedDuplicatePolicy {
    case skip
    case merge
    case duplicate
}
