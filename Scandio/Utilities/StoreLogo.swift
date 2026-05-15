import SwiftUI

/// Maps known store names to their logo SF Symbol or emoji + brand color.
/// Falls back to a generic icon for unknown stores.
enum StoreLogo {
    struct Info {
        let icon: String       // SF Symbol name or emoji
        let isEmoji: Bool
        let colorHex: String   // Brand color
    }

    private static let knownStores: [String: Info] = [
        // Groceries / supermarkets — 🛒
        "biedronka":     Info(icon: "🐞", isEmoji: true, colorHex: "E30613"),
        "lidl":          Info(icon: "🛒", isEmoji: true, colorHex: "0050AA"),
        "auchan":        Info(icon: "🛒", isEmoji: true, colorHex: "E2001A"),
        "carrefour":     Info(icon: "🛒", isEmoji: true, colorHex: "004E9F"),
        "kaufland":      Info(icon: "🛒", isEmoji: true, colorHex: "E10915"),
        "makro":         Info(icon: "🛒", isEmoji: true, colorHex: "003B7E"),
        "selgros":       Info(icon: "🛒", isEmoji: true, colorHex: "E62C2C"),
        "colruyt":       Info(icon: "🛒", isEmoji: true, colorHex: "E20613"),
        "stokrotka":     Info(icon: "🌼", isEmoji: true, colorHex: "E30613"),
        "netto":         Info(icon: "🐕", isEmoji: true, colorHex: "FFD700"),
        "dino":          Info(icon: "🦕", isEmoji: true, colorHex: "009639"),

        // Convenience
        "żabka":         Info(icon: "🐸", isEmoji: true, colorHex: "006B3F"),
        "zabka":         Info(icon: "🐸", isEmoji: true, colorHex: "006B3F"),

        // Pet stores — 🐕
        "maxi zoo":      Info(icon: "🐕", isEmoji: true, colorHex: "75B82A"),
        "kakadu":        Info(icon: "🐕", isEmoji: true, colorHex: "6E2585"),

        // Clothing — 👕
        "giacomo conti": Info(icon: "👕", isEmoji: true, colorHex: "2C2C2C"),
        "h&m":           Info(icon: "👕", isEmoji: true, colorHex: "E50010"),
        "zara":          Info(icon: "👕", isEmoji: true, colorHex: "000000"),
        "pepco":         Info(icon: "👕", isEmoji: true, colorHex: "E4002B"),
        "reserved":      Info(icon: "👗", isEmoji: true, colorHex: "000000"),

        // DIY / hardware
        "castorama":     Info(icon: "🔨", isEmoji: true, colorHex: "0054A6"),
        "castopro":      Info(icon: "🔨", isEmoji: true, colorHex: "0054A6"),
        "leroy merlin":  Info(icon: "🏠", isEmoji: true, colorHex: "78BE20"),

        // Pharmacy / cosmetics
        "rossmann":      Info(icon: "💊", isEmoji: true, colorHex: "E30613"),
        "hebe":          Info(icon: "💄", isEmoji: true, colorHex: "E91E8C"),
        "sephora":       Info(icon: "💄", isEmoji: true, colorHex: "000000"),

        // Jewelry — 💍
        "apart":         Info(icon: "💍", isEmoji: true, colorHex: "1A1A1A"),
        "kruk":          Info(icon: "💍", isEmoji: true, colorHex: "000000"),

        // Home / furniture
        "ikea":          Info(icon: "🪑", isEmoji: true, colorHex: "0058A3"),

        // Sports
        "decathlon":     Info(icon: "⚽", isEmoji: true, colorHex: "0066CC"),

        // Books / media
        "empik":          Info(icon: "📚", isEmoji: true, colorHex: "FFD100"),
        "media markt":    Info(icon: "📺", isEmoji: true, colorHex: "DF0000"),
        "media expert":   Info(icon: "📺", isEmoji: true, colorHex: "ED1C24"),

        // Footwear / discount
        "ccc":            Info(icon: "👟", isEmoji: true, colorHex: "000000"),
        "action":         Info(icon: "🏷️", isEmoji: true, colorHex: "0072CE"),

        // Fuel
        "orlen":          Info(icon: "⛽", isEmoji: true, colorHex: "E30613"),
        "bp":             Info(icon: "⛽", isEmoji: true, colorHex: "009B3A"),
        "shell":          Info(icon: "⛽", isEmoji: true, colorHex: "FFD500"),
        "circle k":       Info(icon: "⛽", isEmoji: true, colorHex: "ED1C24"),
    ]

    /// Memoizes lookups by normalized name. The partial-match path is an O(n)
    /// dict scan and `lookup` is called from every CardRowView body, so we cache
    /// per-name. Annotated `@MainActor` because every caller runs on main and
    /// it gives us free synchronization.
    @MainActor private static var cache: [String: Info?] = [:]

    /// Look up store info by card name. Matches partial/case-insensitive.
    @MainActor
    static func lookup(_ name: String) -> Info? {
        let lowered = name.lowercased().trimmingCharacters(in: .whitespaces)
        if lowered.isEmpty { return nil }
        if let cached = cache[lowered] { return cached }
        let result = computeLookup(lowered)
        cache[lowered] = result
        return result
    }

    private static func computeLookup(_ lowered: String) -> Info? {
        // Exact match first
        if let info = knownStores[lowered] { return info }
        // Partial match — check if the card name contains a known store name
        for (key, info) in knownStores where lowered.contains(key) {
            return info
        }
        return nil
    }

    /// Get the brand color for a card name, or nil if unknown.
    @MainActor
    static func brandColorHex(for name: String) -> String? {
        lookup(name)?.colorHex
    }
}
