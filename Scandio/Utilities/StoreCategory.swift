import Foundation

enum StoreCategory: String, CaseIterable, Identifiable {
    case grocery
    case pet
    case clothing
    case pharmacy
    case fuel
    case furniture
    case sports
    case diy
    case books
    case electronics
    case footwear
    case other

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .grocery:     return "🛒"
        case .pet:         return "🐕"
        case .clothing:    return "👕"
        case .pharmacy:    return "💊"
        case .fuel:        return "⛽"
        case .furniture:   return "🪑"
        case .sports:      return "⚽"
        case .diy:         return "🔨"
        case .books:       return "📚"
        case .electronics: return "📺"
        case .footwear:    return "👟"
        case .other:       return "🏷️"
        }
    }

    var displayName: String {
        switch self {
        case .grocery:     return String(localized: "Grocery")
        case .pet:         return String(localized: "Pet store")
        case .clothing:    return String(localized: "Clothing")
        case .pharmacy:    return String(localized: "Pharmacy")
        case .fuel:        return String(localized: "Fuel")
        case .furniture:   return String(localized: "Furniture")
        case .sports:      return String(localized: "Sports")
        case .diy:         return String(localized: "DIY / Hardware")
        case .books:       return String(localized: "Books / Media")
        case .electronics: return String(localized: "Electronics")
        case .footwear:    return String(localized: "Footwear")
        case .other:       return String(localized: "Other")
        }
    }

    /// Resolve a free-form category guess (e.g. from an LLM) back to a case.
    /// Tolerant: matches by raw value or by display-name fragments.
    static func fromGuess(_ raw: String) -> StoreCategory? {
        let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let direct = StoreCategory(rawValue: lowered) { return direct }
        for cat in StoreCategory.allCases where lowered.contains(cat.rawValue) {
            return cat
        }
        return nil
    }
}
