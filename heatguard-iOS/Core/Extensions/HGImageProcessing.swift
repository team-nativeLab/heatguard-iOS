import Foundation
import ImageIO
import UIKit

struct HGImageProcessing {
    static let maximumEncodedByteCount = 25 * 1_024 * 1_024
    static let maximumPixelDimension = 2_048

    static func downsampledImage(from data: Data) throws -> UIImage {
        guard data.count <= maximumEncodedByteCount else {
            throw HGImageProcessingError.photoTooLarge
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary) else {
            throw HGImageProcessingError.invalidPhoto
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw HGImageProcessingError.invalidPhoto
        }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }

    static func downsampledImage(from image: UIImage) throws -> UIImage {
        let width = CGFloat(image.cgImage?.width ?? Int(image.size.width * image.scale))
        let height = CGFloat(image.cgImage?.height ?? Int(image.size.height * image.scale))
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            throw HGImageProcessingError.invalidPhoto
        }
        let scale = min(1, CGFloat(maximumPixelDimension) / max(width, height))
        guard scale < 1 else { return image }

        let targetSize = CGSize(width: (width * scale).rounded(.down), height: (height * scale).rounded(.down))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized
    }

    static func jpegData(from image: UIImage, maximumByteCount: Int) throws -> Data {
        let optimizedImage = try downsampledImage(from: image)
        for quality in stride(from: 0.9, through: 0.4, by: -0.1) {
            if let data = optimizedImage.jpegData(compressionQuality: quality), data.count <= maximumByteCount {
                return data
            }
        }
        throw HGImageProcessingError.photoTooLarge
    }
}

enum HGImageProcessingError: LocalizedError, Equatable {
    case invalidPhoto
    case photoTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidPhoto:
            "사진 파일을 읽을 수 없습니다. 다른 사진을 선택해주세요."
        case .photoTooLarge:
            "사진 용량이 너무 큽니다. 더 작은 사진을 선택해주세요."
        }
    }
}
