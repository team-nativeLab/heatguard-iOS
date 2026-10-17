import Foundation
import UIKit
import SwiftUI
import XCTest
@testable import heatguard_iOS

@MainActor
final class ChecklistServiceTests: XCTestCase {
    override func tearDown() {
        ChecklistFixtureURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchItemsUsesAuthenticatedChecklistEndpoint() async throws {
        let (service, tokenStore, requests) = try makeService()
        defer { try? tokenStore.clear() }

        let items = try await service.fetchItems()

        XCTAssertEqual(items.count, 6)
        XCTAssertEqual(items[0], HGChecklistItem(id: "item-1", text: "식수 비치 확인", checked: true))
        XCTAssertEqual(items[1], HGChecklistItem(id: "item-2", text: "그늘막 설치 확인", checked: false))
        let request = try XCTUnwrap(requests.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, HGAPIPath.teamChecklist)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer checklist-fixture-token")
    }

    func testUpdateUsesAuthenticatedItemEndpointAndCheckedBody() async throws {
        let (service, tokenStore, requests) = try makeService()
        defer { try? tokenStore.clear() }

        let response = try await service.update(itemID: "item-2", isChecked: true)

        XCTAssertEqual(response.itemID, "item-2")
        XCTAssertTrue(response.checked)
        let request = try XCTUnwrap(requests.requests.first)
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.url?.path, HGAPIPath.teamChecklistItem(id: "item-2"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer checklist-fixture-token")
        let body = try XCTUnwrap(requestBody(for: request))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Bool])
        XCTAssertEqual(json, ["checked": true])
    }

    func testChecklistScreenRendersLoadedItemsAtDesignAndSmallSizes() async throws {
        let (service, tokenStore, _) = try makeService()
        defer { try? tokenStore.clear() }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)

        for size in [CGSize(width: 402, height: 978), CGSize(width: 320, height: 568)] {
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            let view = ChecklistView(
                times: ["08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00", "22:00"],
                siteName: "인천 물류센터",
                teamName: "A팀",
                service: service
            )
            let host = UIHostingController(rootView: NavigationStack { view }.environment(\.colorScheme, .light))
            window.rootViewController = host
            window.makeKeyAndVisible()
            try await Task.sleep(for: .milliseconds(300))
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()

            let image = UIGraphicsImageRenderer(size: size).image { _ in
                host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
            }
            XCTAssertEqual(image.size, size)
            let attachment = XCTAttachment(image: image)
            attachment.name = "checklist-\(Int(size.width))x\(Int(size.height))-fixture"
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
        }
    }

    private func makeService() throws -> (HGChecklistService, HGAuthTokenStore, ChecklistRequestLog) {
        let tokenStore = HGAuthTokenStore(account: "checklist-fixture-\(UUID().uuidString)")
        try tokenStore.save("checklist-fixture-token")
        let requests = ChecklistRequestLog()
        ChecklistFixtureURLProtocol.handler = { request in
            requests.append(request)
            let url = try XCTUnwrap(request.url)
            let payload: [String: Any]
            if request.httpMethod == "PUT" {
                payload = ["success": true, "data": ["itemId": "item-2", "checked": true, "checkedAt": "2026-10-18T00:00:00Z"]]
            } else {
                payload = ["success": true, "data": ["items": [
                    ["itemId": "item-1", "text": "식수 비치 확인", "checked": true],
                    ["itemId": "item-2", "text": "그늘막 설치 확인", "checked": false],
                    ["itemId": "item-3", "text": "근로자 건강상태 확인", "checked": true],
                    ["itemId": "item-4", "text": "옥외작업 자제", "checked": false],
                    ["itemId": "item-5", "text": "정기 휴식 실시", "checked": true],
                    ["itemId": "item-6", "text": "응급처치 키트 위치 확인", "checked": false]
                ]]]
            }
            let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (response, try JSONSerialization.data(withJSONObject: payload))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ChecklistFixtureURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let client = HGAPIClient(session: session, tokenStore: tokenStore)
        return (HGChecklistService(client: client), tokenStore, requests)
    }

    private func requestBody(for request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var body = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            guard count > 0 else { break }
            body.append(buffer, count: count)
        }
        return body.isEmpty ? nil : body
    }
}

private final class ChecklistRequestLog: @unchecked Sendable {
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

private final class ChecklistFixtureURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

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
