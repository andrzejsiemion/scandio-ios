import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class BarcodeGenerator: @unchecked Sendable {

    static let shared = BarcodeGenerator()

    private let cache = NSCache<NSString, UIImage>()
    private let renderQueue = DispatchQueue(label: "com.cards.barcodeRenderer")

    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 20 * 1024 * 1024 // 20MB max

        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }

    /// Generate a barcode image for the given string and type, sized to fit `size`.
    /// Returns nil if the input is invalid for the given barcode type.
    func generate(from string: String, type: BarcodeType, size: CGSize) -> UIImage? {
        let cacheKey = "\(string)-\(type.rawValue)-\(Int(size.width))x\(Int(size.height))" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let image: UIImage?
        switch type {
        case .ean13:
            image = EANRenderer.generateEAN13(from: string, size: size)
        case .ean8:
            image = EANRenderer.generateEAN8(from: string, size: size)
        case .itf:
            image = EANRenderer.generateITF(from: string, size: size)
        case .qrCode:
            image = generateQR(from: string, size: size)
        case .code128:
            image = generateCIFilter(from: string, filterName: "CICode128BarcodeGenerator", size: size)
        case .pdf417:
            image = generateCIFilter(from: string, filterName: "CIPDF417BarcodeGenerator", size: size)
        case .aztec:
            image = generateCIFilter(from: string, filterName: "CIAztecCodeGenerator", size: size)
        }

        if let image {
            cache.setObject(image, forKey: cacheKey)
        }
        return image
    }

    /// Clear the cache (e.g. on memory warning).
    func clearCache() {
        cache.removeAllObjects()
    }

    // MARK: - QR Code

    private func generateQR(from string: String, size: CGSize) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        return renderCIImage(filter.outputImage, targetSize: size)
    }

    // MARK: - Generic CIFilter (Code 128, PDF417, Aztec)

    private func generateCIFilter(from string: String, filterName: String, size: CGSize) -> UIImage? {
        guard let data = string.data(using: .ascii) else { return nil }
        guard let filter = CIFilter(name: filterName) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        return renderCIImage(filter.outputImage, targetSize: size)
    }

    // MARK: - CIImage → UIImage with nearest-neighbor scaling

    private func renderCIImage(_ ciImage: CIImage?, targetSize: CGSize) -> UIImage? {
        guard let ciImage else { return nil }

        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else { return nil }

        // Scale to integer multiple of source pixels for crisp nearest-neighbor
        let scaleX = floor(targetSize.width / extent.width)
        let scaleY = floor(targetSize.height / extent.height)
        let scale = max(min(scaleX, scaleY), 1)

        // Render at 1:1 pixel ratio — no interpolation artifacts
        let outputWidth = Int(extent.width * scale)
        let outputHeight = Int(extent.height * scale)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let bitmapContext = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        bitmapContext.interpolationQuality = .none

        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: extent) else { return nil }

        bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))

        guard let result = bitmapContext.makeImage() else { return nil }
        return UIImage(cgImage: result)
    }
}
