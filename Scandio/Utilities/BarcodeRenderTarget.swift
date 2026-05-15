import CoreGraphics

/// Single source of truth for the texture size at which a barcode is rendered
/// for a given UI surface. Every call site (render + precache) must go through
/// this so cache keys line up and precached entries actually hit.
enum BarcodeRenderTarget {
    case quickAccess
    case preview
    case fullScreen

    func size(for type: BarcodeType) -> CGSize {
        let is2D = type == .qrCode || type == .aztec
        switch self {
        case .quickAccess:
            return is2D ? CGSize(width: 200, height: 200) : CGSize(width: 400, height: 120)
        case .preview:
            return is2D ? CGSize(width: 200, height: 200) : CGSize(width: 300, height: 120)
        case .fullScreen:
            return is2D ? CGSize(width: 280, height: 280) : CGSize(width: 340, height: 180)
        }
    }
}
