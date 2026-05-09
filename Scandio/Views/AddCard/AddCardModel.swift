import SwiftUI
import SwiftData
import PhotosUI

@Observable
@MainActor
final class AddCardModel {
    let existingCard: LoyaltyCard?

    var name: String
    var cardNumber: String
    var barcodeType: BarcodeType
    var validationError: String?
    var selectedColor: Color
    var customHexText: String
    var showCustomColor: Bool

    var logoItem: PhotosPickerItem?
    var logoData: Data?
    var logoImage: UIImage?

    var selectedCategory: StoreCategory?
    var isLoadingAISuggestion: Bool

    @ObservationIgnored private var userChangedType = false
    @ObservationIgnored private var isAutoDetecting = false
    @ObservationIgnored private var aiSuggestionTask: Task<Void, Never>?

    var isEditing: Bool { existingCard != nil }

    static let presetColors: [String] = [
        "007AFF", "34C759", "FF3B30", "FF9500", "AF52DE",
        "FF2D55", "5856D6", "00C7BE", "FFD60A", "8E8E93", "000000"
    ]

    init(existingCard: LoyaltyCard? = nil) {
        self.existingCard = existingCard
        self.name = ""
        self.cardNumber = ""
        self.barcodeType = .ean13
        self.validationError = nil
        self.selectedColor = Color(hex: "007AFF")
        self.customHexText = ""
        self.showCustomColor = false
        self.logoItem = nil
        self.logoData = nil
        self.logoImage = nil
        self.selectedCategory = nil
        self.isLoadingAISuggestion = false

        guard let card = existingCard else { return }
        name = card.name
        cardNumber = card.cardNumber
        barcodeType = card.barcodeType
        selectedColor = Color(hex: card.colorHex)
        if !Self.presetColors.contains(card.colorHex) {
            showCustomColor = true
            customHexText = card.colorHex
        }
        if let data = card.logoData {
            logoData = data
            logoImage = UIImage(data: data)
        }
        if let raw = card.categoryRaw, let cat = StoreCategory(rawValue: raw) {
            selectedCategory = cat
        } else if let stored = card.customIcon,
                  let cat = StoreCategory.allCases.first(where: { $0.icon == stored }) {
            // Backward compat: cards persisted before categoryRaw existed.
            selectedCategory = cat
        }
    }

    // MARK: - Derived

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !cardNumber.isEmpty
    }

    var hasValidNumber: Bool {
        if case .success = validatedNumber() { return true }
        return false
    }

    var showCategoryPicker: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return false }
        if logoImage != nil { return false }
        if StoreLogo.lookup(trimmed) != nil { return false }
        return true
    }

    var inputHint: String? {
        switch barcodeType {
        case .ean13: return String(localized: "Enter 12 or 13 digits (check digit auto-computed)")
        case .ean8:  return String(localized: "Enter 7 or 8 digits (check digit auto-computed)")
        case .itf:   return String(localized: "Enter digits (spaces are stripped automatically)")
        default:     return nil
        }
    }

    var selectedColorHex: String {
        for hex in Self.presetColors where isColorSelected(hex) { return hex }
        let cleaned = customHexText.replacingOccurrences(of: "#", with: "")
        if cleaned.count == 6, cleaned.allSatisfy(\.isHexDigit) {
            return cleaned
        }
        return colorToHex(selectedColor)
    }

    func isColorSelected(_ hex: String) -> Bool {
        if showCustomColor { return false }
        return colorToHex(selectedColor).uppercased() == hex.uppercased()
    }

    private func colorToHex(_ color: Color) -> String {
        let resolved = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    // MARK: - Field handlers

    func nameChanged() {
        if !isEditing, let brandHex = StoreLogo.brandColorHex(for: name) {
            selectedColor = Color(hex: brandHex)
        }
        scheduleCategorySuggestion()
    }

    func barcodeTypeChanged() {
        validationError = nil
        if !isAutoDetecting { userChangedType = true }
    }

    func cardNumberChanged() {
        if !isEditing, !userChangedType,
           let detected = BarcodeType.autoDetect(from: cardNumber) {
            isAutoDetecting = true
            barcodeType = detected
            isAutoDetecting = false
        }
    }

    func customHexChanged() {
        let cleaned = customHexText.replacingOccurrences(of: "#", with: "")
        if cleaned.count == 6, cleaned.allSatisfy(\.isHexDigit) {
            selectedColor = Color(hex: cleaned)
        }
    }

    func selectColor(_ hex: String) {
        showCustomColor = false
        selectedColor = Color(hex: hex)
    }

    func loadLogoFromPickerItem() async {
        if let data = try? await logoItem?.loadTransferable(type: Data.self) {
            logoData = data
            logoImage = UIImage(data: data)
        }
    }

    func removeLogo() {
        logoItem = nil
        logoData = nil
        logoImage = nil
    }

    // MARK: - Validation pipeline (validate AND prepare in one pass)

    func validatedNumber() -> Result<String, ValidationFailure> {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if trimmedName.isEmpty { return .failure(.nameRequired) }

        let trimmedNumber = cardNumber
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
        if trimmedNumber.isEmpty { return .failure(.numberRequired) }

        switch barcodeType {
        case .ean13: return prepareEAN(trimmedNumber, type: .ean13, shortLength: 12, fullLength: 13)
        case .ean8:  return prepareEAN(trimmedNumber, type: .ean8, shortLength: 7, fullLength: 8)
        case .itf:
            guard trimmedNumber.allSatisfy(\.isNumber) else { return .failure(.digitsOnly(.itf)) }
            guard trimmedNumber.count >= 2 else { return .failure(.itfTooShort) }
            return .success(trimmedNumber)
        default:
            return .success(trimmedNumber)
        }
    }

    private func prepareEAN(_ input: String, type: BarcodeType, shortLength: Int, fullLength: Int) -> Result<String, ValidationFailure> {
        guard input.allSatisfy(\.isNumber) else { return .failure(.digitsOnly(type)) }
        let digits = input.compactMap { $0.wholeNumberValue }
        if digits.count == shortLength {
            let check = EANRenderer.computeCheckDigit(digits)
            return .success(input + String(check))
        } else if digits.count == fullLength {
            let check = EANRenderer.computeCheckDigit(Array(digits.dropLast()))
            if digits.last != check { return .failure(.invalidCheckDigit(expected: check)) }
            return .success(input)
        }
        return .failure(.wrongLength(type))
    }

    // MARK: - Save

    @discardableResult
    func save(into modelContext: ModelContext) -> Bool {
        switch validatedNumber() {
        case .failure(let failure):
            validationError = failure.localizedMessage
            return false
        case .success(let finalNumber):
            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            let colorHex = selectedColorHex
            let compressedLogo = prepareLogoData()
            let resolvedCategory: StoreCategory? = (compressedLogo == nil) ? selectedCategory : nil
            let resolvedCustomIcon = resolvedCategory?.icon
            let resolvedCategoryRaw = resolvedCategory?.rawValue

            if let card = existingCard {
                card.name = trimmedName
                card.cardNumber = finalNumber
                card.barcodeType = barcodeType
                card.colorHex = colorHex
                card.logoData = compressedLogo
                card.customIcon = resolvedCustomIcon
                card.categoryRaw = resolvedCategoryRaw
            } else {
                let card = LoyaltyCard(
                    name: trimmedName,
                    cardNumber: finalNumber,
                    barcodeType: barcodeType,
                    colorHex: colorHex
                )
                card.logoData = compressedLogo
                card.customIcon = resolvedCustomIcon
                card.categoryRaw = resolvedCategoryRaw
                modelContext.insert(card)
            }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return true
        }
    }

    private func prepareLogoData() -> Data? {
        guard let image = logoImage else { return nil }
        return ImageResizer.jpegData(from: image, profile: ImageResizer.storageProfile)
    }

    // MARK: - AI category suggestion

    func scheduleCategorySuggestion() {
        aiSuggestionTask?.cancel()
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              logoImage == nil,
              StoreLogo.lookup(trimmed) == nil else {
            isLoadingAISuggestion = false
            return
        }
        guard AICategoryAdvisor.isAvailable else { return }

        isLoadingAISuggestion = true
        aiSuggestionTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            if Task.isCancelled { return }
            let suggestion = await AICategoryAdvisor.suggest(for: trimmed)
            if Task.isCancelled { return }
            await MainActor.run {
                guard let self else { return }
                self.isLoadingAISuggestion = false
                if self.selectedCategory == nil, let suggestion {
                    self.selectedCategory = suggestion
                }
            }
        }
    }
}

enum ValidationFailure: Error, Equatable {
    case nameRequired
    case numberRequired
    case digitsOnly(BarcodeType)
    case wrongLength(BarcodeType)
    case invalidCheckDigit(expected: Int)
    case itfTooShort

    var localizedMessage: String {
        switch self {
        case .nameRequired:
            return String(localized: "Card name is required.")
        case .numberRequired:
            return String(localized: "Card number is required.")
        case .digitsOnly(.ean13):
            return String(localized: "EAN-13 must contain only digits.")
        case .digitsOnly(.ean8):
            return String(localized: "EAN-8 must contain only digits.")
        case .digitsOnly(.itf):
            return String(localized: "ITF must contain only digits.")
        case .digitsOnly:
            return ""
        case .wrongLength(.ean13):
            return String(localized: "EAN-13 requires 12 or 13 digits.")
        case .wrongLength(.ean8):
            return String(localized: "EAN-8 requires 7 or 8 digits.")
        case .wrongLength:
            return ""
        case .invalidCheckDigit(let expected):
            return String(localized: "Invalid check digit. Expected \(expected).")
        case .itfTooShort:
            return String(localized: "ITF requires at least 2 digits.")
        }
    }
}
