import Foundation
import UIKit
import XCTest
@testable import heatguard_iOS

@MainActor
final class RecordUploadVerificationTests: XCTestCase {
    func testUploadUsesAllRequiredHeadersAndChecksSavedPhotos() async throws {
        let (result, requests) = try await saveFixture(.complete)
        XCTAssertEqual(result.expectedPhotoCount, 1)
        XCTAssertEqual(result.photoVerification, .checked(photoURLCount: 1))
        let upload = try XCTUnwrap(requests.first { $0.httpMethod == "PUT" })
        XCTAssertEqual(upload.value(forHTTPHeaderField: "Content-Type"), "image/jpeg")
        XCTAssertEqual(upload.value(forHTTPHeaderField: "x-amz-meta-fixture"), "signed-value")
        XCTAssertEqual(requests.filter { $0.httpMethod == "POST" && $0.url?.path == HGAPIPath.teamRecords }.count, 1)
    }

    func testVerificationFailureKeepsSavedRecordWithoutCreatingAgain() async throws {
        let (result, requests) = try await saveFixture(.detailUnavailable)
        XCTAssertEqual(result.recordID, "fixture-record")
        guard case .unavailable = result.photoVerification else {
            return XCTFail("상세 조회 실패가 저장 실패로 바뀌면 안 됩니다")
        }
        XCTAssertEqual(requests.filter { $0.httpMethod == "POST" && $0.url?.path == HGAPIPath.teamRecords }.count, 1)
    }

    func testMissingPhotoConnectionIsReportedSeparatelyFromSavedRecord() async throws {
        let (result, _) = try await saveFixture(.noConnectedPhotos)
        XCTAssertEqual(result.expectedPhotoCount, 1)
        XCTAssertEqual(result.photoVerification, .checked(photoURLCount: 0))
    }

    func testMissingSignedHeadersFailsBeforeUploadOrRecordCreation() async throws {
        do {
            _ = try await saveFixture(.headersMissing)
            XCTFail("필수 헤더가 없는 업로드 예약은 거부해야 합니다")
        } catch let error as HGRecordUploadError {
            XCTAssertEqual(error.diagnosticCode, "UPLOAD_HEADERS_MISSING")
        }
    }

    private enum Scenario {
        case complete, detailUnavailable, noConnectedPhotos, headersMissing
    }

    private func saveFixture(_ scenario: Scenario) async throws -> (HGRecordSaveResult, [URLRequest]) {
        let tokenStore = HGAuthTokenStore(account: "record-upload-fixture-\(UUID().uuidString)")
        try tokenStore.save("fixture-token")
        defer { try? tokenStore.clear() }

        let log = RequestLog()
        RecordFixtureURLProtocol.handler = { request in
            log.append(request)
            let url = try XCTUnwrap(request.url)
            var status = 200
            let data: Data
            if request.httpMethod == "PUT" {
                data = Data()
            } else if url.path == HGAPIPath.teamUploads {
                var upload: [String: Any] = ["objectKey": "fixture.jpg", "uploadUrl": "https://upload.example.invalid/fixture"]
                if scenario != .headersMissing {
                    upload["requiredHeaders"] = ["Content-Type": "image/jpeg", "x-amz-meta-fixture": "signed-value"]
                }
                data = try JSONSerialization.data(withJSONObject: ["success": true, "data": ["uploads": [upload]]])
            } else if request.httpMethod == "POST", url.path == HGAPIPath.teamRecords {
                data = try JSONSerialization.data(withJSONObject: ["success": true, "data": ["recordId": "fixture-record"]])
            } else if scenario == .detailUnavailable {
                status = 503
                data = try JSONSerialization.data(withJSONObject: [
                    "success": false,
                    "error": ["code": "UNAVAILABLE", "message": "fixture"]
                ])
            } else {
                let urls = scenario == .noConnectedPhotos ? [] : ["https://photos.example.invalid/fixture.jpg"]
                data = try JSONSerialization.data(withJSONObject: ["success": true, "data": [
                    "recordId": "fixture-record", "type": "WORK", "measuredAt": "2026-10-14T00:00:00Z", "photoUrls": urls
                ]])
            }
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)), data)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordFixtureURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
            RecordFixtureURLProtocol.handler = nil
        }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        let service = HGRecordUploadService(client: HGAPIClient(session: session, tokenStore: tokenStore), session: session)
        let result = try await service.save(HGRecordDraft(type: .work, memo: "", temperature: 26, humidity: 41), images: [image])
        return (result, log.requests)
    }
}

private final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URLRequest] = []

    func append(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(request)
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class RecordFixtureURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    // URLProtocol requires class overrides for these methods.
    // swiftlint:disable static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    // swiftlint:enable static_over_final_class

    override func startLoading() {
        do {
            let (response, data) = try XCTUnwrap(Self.handler)(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
