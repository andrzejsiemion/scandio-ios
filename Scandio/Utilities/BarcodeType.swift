import Foundation

enum BarcodeType: String, CaseIterable, Identifiable, Codable {
    case ean13   = "EAN-13"
    case ean8    = "EAN-8"
    case code128 = "Code 128"
    case itf     = "ITF"
    case qrCode  = "QR Code"
    case pdf417  = "PDF417"
    case aztec   = "Aztec"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// The CIFilter name used by Core Image to generate this barcode.
    var ciFilterName: String {
        switch self {
        case .ean13:   return ""
        case .ean8:    return ""
        case .itf:     return ""
        case .code128: return "CICode128BarcodeGenerator"
        case .qrCode:  return "CIQRCodeGenerator"
        case .pdf417:  return "CIPDF417BarcodeGenerator"
        case .aztec:   return "CIAztecCodeGenerator"
        }
    }

    /// Whether this barcode type uses a CIFilter or requires custom drawing.
    var usesCIFilter: Bool {
        switch self {
        case .ean13, .ean8, .itf: return false
        default: return true
        }
    }

    /// Keyboard type appropriate for entering this barcode's data.
    var isNumericOnly: Bool {
        switch self {
        case .ean13, .ean8, .itf: return true
        default: return false
        }
    }

    /// Expected digit count (nil if variable length).
    var expectedDigitCount: Int? {
        switch self {
        case .ean13: return 13
        case .ean8:  return 8
        default:     return nil
        }
    }

    /// Minimum input length (without check digit for EAN types).
    var minInputLength: Int {
        switch self {
        case .ean13: return 12
        case .ean8:  return 7
        case .itf:   return 2
        default:     return 1
        }
    }

    /// Auto-detect the most likely barcode type from user input.
    /// Returns nil if no confident guess can be made.
    static func autoDetect(from input: String) -> BarcodeType? {
        let cleaned = input.replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return nil }

        let isAllDigits = cleaned.allSatisfy(\.isNumber)

        // Non-numeric → likely QR or Code 128
        if !isAllDigits {
            if cleaned.contains("http") || cleaned.contains("://") || cleaned.count > 40 {
                return .qrCode
            }
            return .code128
        }

        // All digits — guess by length
        let count = cleaned.count
        switch count {
        case 7, 8:
            return .ean8
        case 12, 13:
            return .ean13
        case 14...30:
            // Long numeric strings are typically ITF (loyalty cards like Makro)
            return .itf
        default:
            // Short numeric (< 7) or 9-11 digits — Code 128 is safest
            if count >= 2 {
                return .code128
            }
            return nil
        }
    }
}
