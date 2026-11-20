import Foundation
import UIKit
import XCTest
@testable import heatguard_iOS

@MainActor
final class HGProfilePhotoDownloadTests: XCTestCase {
    func testLoadsAndDownsamplesHttpsPhoto() async throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 24), format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
        }
        let imageData = try XCTUnwrap(image.jpegData(compressionQuality: 0.8))
        let service = try makeService(photoResponse: PhotoFixtureResponse(
            status: 200,
            mimeType: "image/jpeg",
            data: imageData
        ))
        let loaded = try await service.loadPhoto()

        XCTAssertEqual(loaded?.cgImage?.width, 32)
        XCTAssertEqual(loaded?.cgImage?.height, 24)
    }

    func testRejectsDeclaredPhotoSizeAboveLimitBeforeReadingBody() async throws {
        let service = try makeService(
            photoResponse: PhotoFixtureResponse(status: 200, mimeType: "image/jpeg", data: Data()),
            declaredPhotoSize: HGImageProcessing.maximumEncodedByteCount + 1
        )

        do {
            _ = try await service.loadPhoto()
            XCTFail("크기 제한을 넘는 사진은 읽지 않아야 합니다")
        } catch let error as HGImageProcessingError {
            XCTAssertEqual(error, .photoTooLarge)
        }
    }

    func testRejectsNonImagePhotoResponse() async throws {
        let service = try makeService(photoResponse: PhotoFixtureResponse(
            status: 200,
            mimeType: "text/html",
            data: Data("not image".utf8)
        ))

        do {
            _ = try await service.loadPhoto()
            XCTFail("이미지 MIME 유형이 아니면 거부해야 합니다")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    private func makeService(
        photoResponse: PhotoFixtureResponse,
        declaredPhotoSize: Int? = nil
    ) throws -> HGProfilePhotoService {
        let tokenStore = HGAuthTokenStore(account: "profile-download-\(UUID().uuidString)")
        try tokenStore.save("fixture-token")
        addTeardownBlock { try? tokenStore.clear() }

        ProfilePhotoDownloadURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            if url.path == HGAPIPath.teamProfilePhoto {
                let body = try JSONSerialization.data(withJSONObject: [
                    "success": true,
                    "data": ["photoUrl": "https://photos.example.invalid/profile.jpg"]
                ])
                return (
                    try XCTUnwrap(HTTPURLResponse(
                        url: url,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )),
                    body
                )
            }

            var headers = ["Content-Type": photoResponse.mimeType]
            if let declaredPhotoSize {
                headers["Content-Length"] = String(declaredPhotoSize)
            }
            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: url,
                    statusCode: photoResponse.status,
                    httpVersion: nil,
                    headerFields: headers
                )),
                photoResponse.data
            )
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProfilePhotoDownloadURLProtocol.self]
        let session = URLSession(configuration: configuration)
        addTeardownBlock {
            session.invalidateAndCancel()
            ProfilePhotoDownloadURLProtocol.handler = nil
        }
        return HGProfilePhotoService(
            client: HGAPIClient(session: session, tokenStore: tokenStore),
            session: session
        )
    }
}

private struct PhotoFixtureResponse {
    let status: Int
    let mimeType: String
    let data: Data
}

private final class ProfilePhotoDownloadURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    // URLProtocol requires class overrides for these methods.
    // swiftlint:disable static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    // swiftlint:enable static_over_final_class

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
