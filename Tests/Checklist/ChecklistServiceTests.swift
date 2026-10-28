import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import heatguard_iOS

@MainActor
final class ChecklistServiceTests: XCTestCase {
    override func tearDown() {
        ChecklistFixtureURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchItemsUsesAuthenticatedChecklistEndpoint() async throws {
        let harness = try makeService { _ in
            (
                200,
                #"{"success":true,"data":{"items":[{"itemId":"item-1","text":"식수 비치 확인","checked":true}]}}"#
            )
        }
        defer { try? harness.tokenStore.clear() }

        let items = try await harness.service.fetchItems()

        XCTAssertEqual(items, [HGChecklistItem(id: "item-1", text: "식수 비치 확인", checked: true)])
        let request = try XCTUnwrap(harness.requests.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, HGAPIPath.teamChecklist)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer checklist-fixture-token")
    }

    func testUpdateUsesAuthenticatedItemEndpointAndCheckedBody() async throws {
        let harness = try makeService { _ in
            (
                200,
                #"{"success":true,"data":{"itemId":"item-1","checked":true,"checkedAt":"2026-10-28T00:00:00Z"}}"#
            )
        }
        defer { try? harness.tokenStore.clear() }

        let response = try await harness.service.update(itemID: "item-1", isChecked: true)

        XCTAssertEqual(response.itemID, "item-1")
        XCTAssertTrue(response.checked)
        let request = try XCTUnwrap(harness.requests.requests.first)
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(request.url?.path, HGAPIPath.teamChecklistItem(id: "item-1"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer checklist-fixture-token")
        let body = try XCTUnwrap(requestBody(for: request))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Bool])
        XCTAssertEqual(payload, ["checked": true])
    }

    func testChecklistScreenRendersAtFigmaCanvasSize() async throws {
        let harness = try makeService { _ in
            (
                200,
                #"""
                {"success":true,"data":{"items":[
                  {"itemId":"item-1","text":"식수(음용수) 비치 확인","checked":true},
                  {"itemId":"item-2","text":"그늘막·휴게시설 설치 확인","checked":true},
                  {"itemId":"item-3","text":"근로자 건강상태(온열질환 증상) 확인","checked":false},
                  {"itemId":"item-4","text":"무더위 시간대(14~17시) 옥외작업 자제","checked":false},
                  {"itemId":"item-5","text":"2시간마다 20분 이상 휴식 실시","checked":true},
                  {"itemId":"item-6","text":"응급처치 키트 위치 확인","checked":false}
                ]}}
                """#
            )
        }
        defer { try? harness.tokenStore.clear() }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let size = CGSize(width: 402, height: 978)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        let view = ChecklistView(
            times: ["08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00", "22:00"],
            siteName: "인천 복합물류센터 신축",
            teamName: "A팀",
            service: harness.service
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
        attachment.name = "checklist-figma-402x978"
        attachment.lifetime = .keepAlways
        add(attachment)
        window.isHidden = true
    }

    private func makeService(
        handler: @escaping (URLRequest) -> (Int, String)
    ) throws -> ChecklistServiceTestHarness {
        let tokenStore = HGAuthTokenStore(account: "checklist-fixture-\(UUID().uuidString)")
        try tokenStore.save("checklist-fixture-token")
        let requests = ChecklistRequestLog()
        ChecklistFixtureURLProtocol.handler = { request in
            requests.append(request)
            let (status, body) = handler(request)
            let response = try XCTUnwrap(
                HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: status, httpVersion: nil, headerFields: nil)
            )
            return (response, Data(body.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ChecklistFixtureURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return ChecklistServiceTestHarness(
            service: HGChecklistService(client: HGAPIClient(session: session, tokenStore: tokenStore)),
            tokenStore: tokenStore,
            requests: requests
        )
    }

    private func requestBody(for request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var body = Data()
        let bufferSize = 1_024
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

private struct ChecklistServiceTestHarness {
    let service: HGChecklistService
    let tokenStore: HGAuthTokenStore
    let requests: ChecklistRequestLog
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

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

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
