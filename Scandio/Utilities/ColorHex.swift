import SwiftUI

extension Color {
    /// Lossy initializer — falls back to system blue if the hex string is
    /// malformed. Used by render-time paths where a missing color shouldn't
    /// produce a runtime error.
    init(hex: String) {
        self = Color.fromHex(hex) ?? Color(red: 0, green: 0.478, blue: 1)
    }

    /// Validating constructor — returns nil for non-6-char or non-hex input.
    /// Use at input boundaries when invalid hex should be surfaced.
    static func fromHex(_ hex: String) -> Color? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, cleaned.allSatisfy(\.isHexDigit) else { return nil }
        var int: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&int) else { return nil }
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}
