import UIKit

/// Image resize / JPEG compression helpers used by both upload-time
/// (storage) and backup-time paths.
enum ImageResizer {
    /// Storage profile — first resize when the user picks a photo.
    /// 256 px on the longest edge, JPEG 0.8.
    static let storageProfile = Profile(maxEdge: 256, jpegQuality: 0.8)

    /// Backup profile — defensive re-resize when writing a `.scandiobackup`.
    /// 192 px on the longest edge, JPEG 0.75.
    static let backupProfile = Profile(maxEdge: 192, jpegQuality: 0.75)

    struct Profile {
        let maxEdge: CGFloat
        let jpegQuality: CGFloat
    }

    /// Resize a `UIImage` to fit within the given profile and return JPEG bytes.
    /// Returns nil only if JPEG encoding itself fails.
    static func jpegData(from image: UIImage, profile: Profile) -> Data? {
        let resized = resized(image, maxEdge: profile.maxEdge)
        return resized.jpegData(compressionQuality: profile.jpegQuality)
    }

    /// Decode `data` and re-encode it through the profile. Falls back to the
    /// original bytes if anything in the pipeline fails.
    static func compressed(_ data: Data, profile: Profile) -> Data {
        guard let image = UIImage(data: data) else { return data }
        return jpegData(from: image, profile: profile) ?? data
    }

    private static func resized(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let scale = min(maxEdge / image.size.width, maxEdge / image.size.height, 1.0)
        guard scale < 0.99 else { return image }
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
