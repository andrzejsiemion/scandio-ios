import Foundation
import SwiftData

/// Codable representation of a LoyaltyCard for backup/restore.
struct CardBackup: Codable {
    var name: String
    var cardNumber: String
    var barcodeType: String
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date
    var lastUsedAt: Date?
    var isFavorite: Bool?
    var customIcon: String?
    var categoryRaw: String?
    var logoBase64: String?

    init(from card: LoyaltyCard) {
        self.name = card.name
        self.cardNumber = card.cardNumber
        self.barcodeType = card.barcodeTypeRaw
        self.colorHex = card.colorHex
        self.sortOrder = card.sortOrder
        self.createdAt = card.createdAt
        self.lastUsedAt = card.lastUsedAt
        self.isFavorite = card.isFavorite
        self.customIcon = card.customIcon
        self.categoryRaw = card.categoryRaw
        // Re-resize at backup time as a safety net so backups stay small even
        // if logoData was stored before the upload-time resize existed.
        self.logoBase64 = card.logoData.map {
            ImageResizer.compressed($0, profile: ImageResizer.backupProfile).base64EncodedString()
        }
    }

    /// Max logo size: 1MB after base64 decode
    private static let maxLogoBytes = 1_024_000

    func toLoyaltyCard() -> LoyaltyCard {
        let type = BarcodeType(rawValue: barcodeType) ?? .ean13
        let safeName = String(name.prefix(200))
        let safeNumber = String(cardNumber.prefix(200))
        let safeColor = colorHex.count == 6 && colorHex.allSatisfy(\.isHexDigit) ? colorHex : "007AFF"

        let card = LoyaltyCard(
            name: safeName,
            cardNumber: safeNumber,
            barcodeType: type,
            colorHex: safeColor,
            sortOrder: sortOrder
        )
        card.createdAt = createdAt
        // Note: lastUsedAt is intentionally not restored on import.
        // The backup preserves it for future use (e.g. cross-device sync),
        // but freshly-imported cards should not appear in Quick Access until
        // the user actually opens them on this device.
        card.isFavorite = isFavorite ?? false
        card.customIcon = customIcon
        card.categoryRaw = categoryRaw
        if let base64 = logoBase64,
           let data = Data(base64Encoded: base64),
           data.count <= Self.maxLogoBytes {
            card.logoData = data
        }
        return card
    }
}

struct CardsBackupFile: Codable {
    var version: Int = 1
    var exportDate: Date
    var cards: [CardBackup]
}

enum BackupManager {
    static func exportCards(_ cards: [LoyaltyCard]) throws -> Data {
        let backup = CardsBackupFile(
            exportDate: .now,
            cards: cards.map { CardBackup(from: $0) }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static let currentVersion = 1

    static func importCards(from data: Data) throws -> [LoyaltyCard] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(CardsBackupFile.self, from: data)
        guard backup.version <= currentVersion else {
            throw BackupError.unsupportedVersion(backup.version)
        }
        return backup.cards.map { $0.toLoyaltyCard() }
    }

    /// Phase 1 of import: read the file from a (possibly security-scoped) URL
    /// and decode the cards. Caller can then count duplicates against the
    /// existing list and decide on a policy before calling `apply`.
    @MainActor
    static func parse(from url: URL) -> Result<[LoyaltyCard], Error> {
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsScopedAccess { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let data = try Data(contentsOf: url)
            return .success(try importCards(from: data))
        } catch {
            return .failure(error)
        }
    }

    /// Phase 2 of import: apply parsed cards according to a duplicate policy.
    @MainActor
    static func apply(
        incoming: [LoyaltyCard],
        into modelContext: ModelContext,
        existing: [LoyaltyCard],
        policy: ResolvedDuplicatePolicy
    ) -> ImportResult {
        var added = 0
        var merged = 0
        var skipped = 0

        // Index existing cards by (name, cardNumber) for O(1) duplicate lookup.
        var existingIndex: [String: LoyaltyCard] = [:]
        existingIndex.reserveCapacity(existing.count)
        for card in existing {
            existingIndex[Self.dupKey(name: card.name, number: card.cardNumber)] = card
        }

        for card in incoming {
            let match = existingIndex[Self.dupKey(name: card.name, number: card.cardNumber)]
            switch (match, policy) {
            case (nil, _):
                modelContext.insert(card)
                added += 1
            case (_, .skip):
                skipped += 1
            case (let existingCard?, .merge):
                existingCard.barcodeType = card.barcodeType
                existingCard.colorHex = card.colorHex
                existingCard.sortOrder = card.sortOrder
                existingCard.isFavorite = card.isFavorite
                existingCard.customIcon = card.customIcon
                existingCard.categoryRaw = card.categoryRaw
                existingCard.logoData = card.logoData
                merged += 1
            case (_?, .duplicate):
                modelContext.insert(card)
                added += 1
            }
        }

        return .summary(added: added, merged: merged, skipped: skipped)
    }

    /// How many of `incoming` already exist in `existing` by (name, cardNumber).
    static func duplicateCount(of incoming: [LoyaltyCard], in existing: [LoyaltyCard]) -> Int {
        var existingKeys: Set<String> = []
        existingKeys.reserveCapacity(existing.count)
        for card in existing {
            existingKeys.insert(dupKey(name: card.name, number: card.cardNumber))
        }
        return incoming.reduce(0) { count, card in
            existingKeys.contains(dupKey(name: card.name, number: card.cardNumber)) ? count + 1 : count
        }
    }

    /// Single-key encoding for the (name, cardNumber) duplicate identity.
    /// `\u{1F}` (Unit Separator) cannot appear in user-entered names/numbers.
    private static func dupKey(name: String, number: String) -> String {
        "\(name)\u{1F}\(number)"
    }

    enum ImportResult {
        case summary(added: Int, merged: Int, skipped: Int)
        case failure(Error)

        var localizedMessage: String {
            switch self {
            case .summary(let added, let merged, let skipped):
                return String(localized: "Imported \(added), merged \(merged), skipped \(skipped).")
            case .failure(let error):
                return String(localized: "Import failed: \(error.localizedDescription)")
            }
        }
    }

    enum BackupError: LocalizedError {
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let v):
                return String(localized: "Backup version \(v) is not supported. Please update the app.")
            }
        }
    }
}
