import Foundation
import SwiftData

@Model
final class LoyaltyCard {
    var name: String
    var cardNumber: String
    var barcodeTypeRaw: String
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date
    var lastUsedAt: Date?
    var isFavorite: Bool = false
    /// User-picked or AI-suggested icon (single emoji). Falls back to `StoreLogo.lookup` when nil.
    var customIcon: String?
    /// `StoreCategory.rawValue` of the picked category. Source of truth — `customIcon`
    /// is derived from this on save, kept as a denormalized cache for render-time use.
    var categoryRaw: String?
    @Attribute(.externalStorage) var logoData: Data?

    init(
        name: String,
        cardNumber: String,
        barcodeType: BarcodeType,
        colorHex: String = "007AFF",
        sortOrder: Int = 0
    ) {
        self.name = name
        self.cardNumber = cardNumber
        self.barcodeTypeRaw = barcodeType.rawValue
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = .now
        self.lastUsedAt = nil
        self.isFavorite = false
        self.customIcon = nil
        self.categoryRaw = nil
        self.logoData = nil
    }

    @Transient
    var barcodeType: BarcodeType {
        get { BarcodeType(rawValue: barcodeTypeRaw) ?? .ean13 }
        set { barcodeTypeRaw = newValue.rawValue }
    }
}
