import UIKit
import XCTest
@testable import heatguard_iOS

@MainActor
final class HGImageProcessingTests: XCTestCase {
    func testDownsampledPhotoDoesNotExceedMaximumPixelDimension() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 2_500, height: 4)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2_500, height: 4))
        }
        let encoded = try XCTUnwrap(source.jpegData(compressionQuality: 0.8))
        let image = try HGImageProcessing.downsampledImage(from: encoded)

        XCTAssertLessThanOrEqual(try XCTUnwrap(image.cgImage).width, HGImageProcessing.maximumPixelDimension)
    }

    func testRejectsInvalidImageData() {
        XCTAssertThrowsError(try HGImageProcessing.downsampledImage(from: Data("not an image".utf8)))
    }

    func testRejectsPhotoDataAboveEncodedByteLimit() {
        let oversizedData = Data(count: HGImageProcessing.maximumEncodedByteCount + 1)
        XCTAssertThrowsError(try HGImageProcessing.downsampledImage(from: oversizedData)) { error in
            XCTAssertEqual(error as? HGImageProcessingError, .photoTooLarge)
        }
    }
}
