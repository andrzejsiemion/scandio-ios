import UIKit

/// Custom renderer for EAN-13 and EAN-8 barcodes using CGContext.
/// Core Image lacks dedicated CIFilters for these formats.
enum EANRenderer {

    // MARK: - Public

    /// Render an EAN-13 barcode. Accepts 12 digits (check digit computed) or 13 digits (validated).
    static func generateEAN13(from string: String, size: CGSize) -> UIImage? {
        let digits = normalizeAndValidate(string, expectedFull: 13, expectedShort: 12)
        guard let digits, digits.count == 13 else { return nil }
        let pattern = encodeEAN13(digits)
        return drawBarcode(pattern: pattern, size: size)
    }

    /// Render an EAN-8 barcode. Accepts 7 digits (check digit computed) or 8 digits (validated).
    static func generateEAN8(from string: String, size: CGSize) -> UIImage? {
        let digits = normalizeAndValidate(string, expectedFull: 8, expectedShort: 7)
        guard let digits, digits.count == 8 else { return nil }
        let pattern = encodeEAN8(digits)
        return drawBarcode(pattern: pattern, size: size)
    }

    /// Compute EAN check digit for a digit array (without the check digit).
    static func computeCheckDigit(_ digits: [Int]) -> Int {
        var sum = 0
        for (i, d) in digits.enumerated() {
            sum += (i % 2 == 0) ? d : d * 3
        }
        return (10 - (sum % 10)) % 10
    }

    // MARK: - Validation

    private static func normalizeAndValidate(_ string: String, expectedFull: Int, expectedShort: Int) -> [Int]? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard trimmed.allSatisfy(\.isNumber) else { return nil }
        var digits = trimmed.compactMap { $0.wholeNumberValue }

        if digits.count == expectedShort {
            digits.append(computeCheckDigit(digits))
        } else if digits.count == expectedFull {
            guard let provided = digits.last else { return nil }
            let computed = computeCheckDigit(Array(digits.dropLast()))
            guard provided == computed else { return nil }
        } else {
            return nil
        }
        return digits
    }

    // MARK: - EAN-13 Encoding

    /// L-code patterns (odd parity) for digits 0-9.
    /// Each entry is a 7-bit module pattern: 1 = black bar, 0 = white space.
    private static let lPatterns: [[Int]] = [
        [0,0,0,1,1,0,1], // 0
        [0,0,1,1,0,0,1], // 1
        [0,0,1,0,0,1,1], // 2
        [0,1,1,1,1,0,1], // 3
        [0,1,0,0,0,1,1], // 4
        [0,1,1,0,0,0,1], // 5
        [0,1,0,1,1,1,1], // 6
        [0,1,1,1,0,1,1], // 7
        [0,1,1,0,1,1,1], // 8
        [0,0,0,1,0,1,1], // 9
    ]

    /// G-code patterns (even parity) for digits 0-9.
    private static let gPatterns: [[Int]] = [
        [0,1,0,0,1,1,1], // 0
        [0,1,1,0,0,1,1], // 1
        [0,0,1,1,0,1,1], // 2
        [0,1,0,0,0,0,1], // 3  — intentionally not a typo, per GS1 spec
        [0,0,1,1,1,0,1], // 4
        [0,1,1,1,0,0,1], // 5
        [0,0,0,0,1,0,1], // 6
        [0,0,1,0,0,0,1], // 7
        [0,0,0,1,0,0,1], // 8
        [0,0,1,0,1,1,1], // 9
    ]

    /// R-code patterns for digits 0-9.
    private static let rPatterns: [[Int]] = [
        [1,1,1,0,0,1,0], // 0
        [1,1,0,0,1,1,0], // 1
        [1,1,0,1,1,0,0], // 2
        [1,0,0,0,0,1,0], // 3
        [1,0,1,1,1,0,0], // 4
        [1,0,0,1,1,1,0], // 5
        [1,0,1,0,0,0,0], // 6
        [1,0,0,0,1,0,0], // 7
        [1,0,0,1,0,0,0], // 8
        [1,1,1,0,1,0,0], // 9
    ]

    /// Parity patterns for the left-hand digits, indexed by the first (number system) digit.
    /// L = 0, G = 1
    private static let parityPatterns: [[Int]] = [
        [0,0,0,0,0,0], // 0: LLLLLL
        [0,0,1,0,1,1], // 1: LLGLGG
        [0,0,1,1,0,1], // 2: LLGGLY
        [0,0,1,1,1,0], // 3: LLGGGL
        [0,1,0,0,1,1], // 4: LGLLGG
        [0,1,1,0,0,1], // 5: LGGLLY
        [0,1,1,1,0,0], // 6: LGGGLV
        [0,1,0,1,0,1], // 7: LGLGLG
        [0,1,0,1,1,0], // 8: LGLGGL
        [0,1,1,0,1,0], // 9: LGGLGL
    ]

    private static func encodeEAN13(_ digits: [Int]) -> [Int] {
        var pattern: [Int] = []

        // Start guard: 101
        pattern.append(contentsOf: [1, 0, 1])

        let firstDigit = digits[0]
        let parity = parityPatterns[firstDigit]

        // Left side: digits[1...6], encoded as L or G based on parity
        for i in 0..<6 {
            let digit = digits[i + 1]
            if parity[i] == 0 {
                pattern.append(contentsOf: lPatterns[digit])
            } else {
                pattern.append(contentsOf: gPatterns[digit])
            }
        }

        // Center guard: 01010
        pattern.append(contentsOf: [0, 1, 0, 1, 0])

        // Right side: digits[7...12], all R-encoded
        for i in 7...12 {
            pattern.append(contentsOf: rPatterns[digits[i]])
        }

        // End guard: 101
        pattern.append(contentsOf: [1, 0, 1])

        return pattern
    }

    // MARK: - EAN-8 Encoding

    private static func encodeEAN8(_ digits: [Int]) -> [Int] {
        var pattern: [Int] = []

        // Start guard: 101
        pattern.append(contentsOf: [1, 0, 1])

        // Left side: digits[0...3], all L-encoded
        for i in 0...3 {
            pattern.append(contentsOf: lPatterns[digits[i]])
        }

        // Center guard: 01010
        pattern.append(contentsOf: [0, 1, 0, 1, 0])

        // Right side: digits[4...7], all R-encoded
        for i in 4...7 {
            pattern.append(contentsOf: rPatterns[digits[i]])
        }

        // End guard: 101
        pattern.append(contentsOf: [1, 0, 1])

        return pattern
    }

    // MARK: - ITF (Interleaved 2 of 5)

    /// Render an ITF barcode. Accepts any even number of digits (≥2).
    /// If odd count, a leading zero is prepended.
    static func generateITF(from string: String, size: CGSize) -> UIImage? {
        let cleaned = string.filter(\.isNumber)
        guard cleaned.count >= 2 else { return nil }
        var digits = cleaned.compactMap { $0.wholeNumberValue }
        // ITF requires even number of digits
        if digits.count % 2 != 0 {
            digits.insert(0, at: 0)
        }
        let pattern = encodeITF(digits)
        return drawBarcode(pattern: pattern, size: size)
    }

    /// ITF bar patterns for digits 0-9.
    /// Each digit is encoded as 5 elements: N=narrow, W=wide.
    /// 1=wide, 0=narrow
    private static let itfPatterns: [[Int]] = [
        [0,0,1,1,0], // 0: NNWWN
        [1,0,0,0,1], // 1: WNNNE
        [0,1,0,0,1], // 2: NWNNW
        [1,1,0,0,0], // 3: WWNNN
        [0,0,1,0,1], // 4: NNWNW
        [1,0,1,0,0], // 5: WNWNN
        [0,1,1,0,0], // 6: NWWNN
        [0,0,0,1,1], // 7: NNNWW
        [1,0,0,1,0], // 8: WNNWN
        [0,1,0,1,0], // 9: NWNWN
    ]

    private static func encodeITF(_ digits: [Int]) -> [Int] {
        let narrow = 1
        let wide = 3
        var pattern: [Int] = []
        pattern.reserveCapacity(8 + digits.count * 9 + 5)

        @inline(__always) func append(_ value: Int, count: Int) {
            for _ in 0..<count { pattern.append(value) }
        }

        // Start pattern: narrow black, narrow white, narrow black, narrow white
        append(1, count: narrow)
        append(0, count: narrow)
        append(1, count: narrow)
        append(0, count: narrow)

        // Encode digit pairs
        for i in stride(from: 0, to: digits.count, by: 2) {
            let bars = itfPatterns[digits[i]]
            let spaces = itfPatterns[digits[i + 1]]
            for j in 0..<5 {
                append(1, count: bars[j] == 1 ? wide : narrow)
                append(0, count: spaces[j] == 1 ? wide : narrow)
            }
        }

        // Stop pattern: wide bar, narrow space, narrow bar
        append(1, count: wide)
        append(0, count: narrow)
        append(1, count: narrow)

        return pattern
    }

    // MARK: - Drawing

    private static func drawBarcode(pattern: [Int], size: CGSize) -> UIImage {
        let moduleCount = pattern.count
        let moduleWidth = size.width / CGFloat(moduleCount)
        let height = size.height

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // White background
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Draw black bars on pixel-aligned start/end positions so adjacent
            // bars don't overlap (the previous `ceil(moduleWidth)` approach
            // produced overlapping rects and uneven anti-aliasing).
            UIColor.black.setFill()
            for (i, module) in pattern.enumerated() where module == 1 {
                let xStart = (CGFloat(i) * moduleWidth).rounded()
                let xEnd = (CGFloat(i + 1) * moduleWidth).rounded()
                let rect = CGRect(x: xStart, y: 0, width: xEnd - xStart, height: height)
                ctx.fill(rect)
            }
        }
    }
}
