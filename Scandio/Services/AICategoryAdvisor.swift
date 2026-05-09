import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Wraps Apple Intelligence's on-device language model to suggest a `StoreCategory`
/// for a given store name. Only functional on iOS 26+ Apple-Intelligence-capable
/// devices; callers must check `isAvailable` first.
enum AICategoryAdvisor {

    /// Whether the on-device model can be used right now.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
        }
        #endif
        return false
    }

    /// Suggest a category for the given store name. Returns nil if the model is
    /// unavailable, the response can't be parsed, or anything throws.
    static func suggest(for storeName: String) async -> StoreCategory? {
        let trimmed = storeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }

        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *), isAvailable else { return nil }

        let categoryList = StoreCategory.allCases
            .map { "- \($0.rawValue)" }
            .joined(separator: "\n")

        let instructions = """
        You classify retail store names into one short category code. \
        Reply with ONLY the category code, lowercase, no punctuation, no extra text.
        """
        let prompt = """
        Store name: "\(trimmed)"
        Pick exactly one from this list:
        \(categoryList)
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return StoreCategory.fromGuess(response.content)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
