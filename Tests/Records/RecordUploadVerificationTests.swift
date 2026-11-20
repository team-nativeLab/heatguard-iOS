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
        XCTAssertNil(upload.value(forHTTPHeaderField: "Authorization"))
        let preparation = try XCTUnwrap(requests.first { $0.url?.path == HGAPIPath.teamUploads })
        let body = try XCTUnwrap(preparation.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let file = try XCTUnwrap((json["files"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(file.keys), ["contentType", "size"])
        XCTAssertGreaterThan(try XCTUnwrap(file["size"] as? Int), 0)
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

    func testExpiredReservationIsRenewedAndOnlyNewObjectKeyIsSaved() async throws {
        let (_, requests) = try await saveFixture(.expiredOnce)
        XCTAssertEqual(requests.filter { $0.url?.path == HGAPIPath.teamUploads }.count, 2)
        XCTAssertEqual(requests.filter { $0.httpMethod == "PUT" }.count, 1)
        let save = try XCTUnwrap(requests.first { $0.url?.path == HGAPIPath.teamRecords })
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(save.httpBody)) as? [String: Any])
        XCTAssertEqual(json["photoKeys"] as? [String], ["fixture-2.jpg"])
    }

    func testRepeatedExpirationStopsAfterOneRenewal() async throws {
        do {
            _ = try await saveFixture(.alwaysExpired)
            XCTFail("Repeated expiration must fail")
        } catch let error as HGRecordUploadError {
            XCTAssertEqual(error.diagnosticCode, "UPLOAD_EXPIRED")
        }
    }

    func testUnexpiredForbiddenUploadIsNotRetried() async throws {
        do {
            _ = try await saveFixture(.forbidden)
            XCTFail("Unexpired 403 must fail")
        } catch let error as HGRecordUploadError {
            XCTAssertEqual(error.diagnosticCode, "S3_UPLOAD_HTTP_403")
        }
    }

    func testPhotoByteLimitIncludesExactlyFiveMiB() throws {
        XCTAssertNoThrow(try HGRecordUploadService.validatePhotoSize(5_242_880))
        XCTAssertThrowsError(try HGRecordUploadService.validatePhotoSize(5_242_881))
        XCTAssertThrowsError(try HGRecordUploadService.validatePhotoSize(0))
    }

    func testProfileRenewalFinalizesOnlyNewUploadID() async throws {
        let requests = try await uploadProfileFixture(expired: true)
        XCTAssertEqual(requests.filter { $0.httpMethod == "POST" }.count, 2)
        let finalize = try XCTUnwrap(requests.first { $0.url?.path == HGAPIPath.teamProfilePhoto })
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(finalize.httpBody)) as? [String: String])
        XCTAssertEqual(json, ["uploadId": "avatar-2"])
        let put = try XCTUnwrap(requests.first { $0.url?.host == "upload.example.invalid" })
        XCTAssertNil(put.value(forHTTPHeaderField: "Authorization"))
        XCTAssertNotNil(put.value(forHTTPHeaderField: "Content-Length"))
    }

    private func uploadProfileFixture(expired: Bool) async throws -> [URLRequest] {
        let store = HGAuthTokenStore(account: "profile-upload-fixture-\(UUID().uuidString)")
        try store.save("fixture-token")
        defer { try? store.clear() }
        let log = RequestLog()
        RecordFixtureURLProtocol.handler = { request in
            log.append(request)
            let url = try XCTUnwrap(request.url)
            let data: Data
            if request.httpMethod == "POST" {
                let attempt = log.requests.filter { $0.httpMethod == "POST" }.count
                XCTAssertLessThanOrEqual(attempt, 2)
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
                let size = try XCTUnwrap(json["size"] as? Int)
                XCTAssertEqual(Set(json.keys), ["contentType", "size"])
                data = try JSONSerialization.data(withJSONObject: ["success": true, "data": [
                    "uploadId": "avatar-\(attempt)",
                    "uploadUrl": "https://upload.example.invalid/avatar-\(attempt)",
                    "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(expired && attempt == 1 ? -60 : 300)),
                    "requiredHeaders": ["Content-Type": "image/jpeg", "Content-Length": String(size)]
                ]])
            } else if url.path == HGAPIPath.teamProfilePhoto {
                data = try JSONSerialization.data(withJSONObject: ["success": true, "data": ["photoUrl": NSNull(), "expiresAt": NSNull()]])
            } else {
                data = Data()
            }
            return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)), data)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RecordFixtureURLProtocol.self]
        let session = URLSession(configuration: config)
        defer {
            session.invalidateAndCancel()
            RecordFixtureURLProtocol.handler = nil
        }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in
            UIColor.blue.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        try await HGProfilePhotoService(client: HGAPIClient(session: session, tokenStore: store), session: session).uploadPhoto(image)
        return log.requests
    }

    private enum Scenario {
        case complete, detailUnavailable, noConnectedPhotos, headersMissing, expiredOnce, alwaysExpired, forbidden
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
                if scenario == .forbidden {
                    XCTAssertEqual(log.requests.filter { $0.url?.path == HGAPIPath.teamUploads }.count, 1)
                }
                status = scenario == .forbidden ? 403 : 200
                data = Data("<Error><Code>AccessDenied</Code></Error>".utf8)
            } else if url.path == HGAPIPath.teamUploads {
                let attempt = log.requests.filter { $0.url?.path == HGAPIPath.teamUploads }.count
                let expired = scenario == .alwaysExpired || (scenario == .expiredOnce && attempt == 1)
                XCTAssertLessThanOrEqual(attempt, 2)
                var upload: [String: Any] = [
                    "objectKey": "fixture-\(attempt).jpg",
                    "uploadId": "up-\(attempt)",
                    "expiresAt": ISO8601DateFormatter().string(from: Date().addingTimeInterval(expired ? -60 : 300)),
                    "uploadUrl": "https://upload.example.invalid/fixture"
                ]
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
            var capturedRequest = request
            if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var body = Data()
                var buffer = [UInt8](repeating: 0, count: 8_192)
                while true {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count >= 0 else { throw URLError(.cannotDecodeRawData) }
                    if count == 0 { break }
                    body.append(contentsOf: buffer.prefix(count))
                }
                capturedRequest.httpBody = body
            }
            let (response, data) = try XCTUnwrap(Self.handler)(capturedRequest)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
