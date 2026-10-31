import ImageIO
import UIKit

enum HGPhotoImageProcessor {
    private static let maximumPixelDimension = 2_048

    static func downsample(data: Data) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
            kCGImageSourceShouldCache: false
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: thumbnail)
    }

    static func downsample(image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let sourcePixelSize = max(cgImage.width, cgImage.height)
        guard sourcePixelSize > maximumPixelDimension else { return image }

        let scale = CGFloat(maximumPixelDimension) / CGFloat(sourcePixelSize)
        let targetSize = CGSize(
            width: image.size.width * scale * image.scale,
            height: image.size.height * scale * image.scale
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
