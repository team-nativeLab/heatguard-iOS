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

    func testFetchRoundsUsesDateQueryAndDecodesServerSummary() async throws {
        let harness = try makeService { _ in
            (
                200,
                #"""
                {
                    "success": true,
                    "data": {
                        "date": "2026-10-30",
                        "teamId": "team_01",
                        "summary": {
                            "totalRounds": 3,
                            "completedRounds": 1,
                            "missedRounds": 0,
                            "remainingRounds": 2,
                            "progressPercent": 33
                        },
                        "items": [
                            {
                                "roundId": "08:00",
                                "startsAt": "2026-10-30T08:00:00+09:00",
                                "endsAt": "2026-10-30T10:00:00+09:00",
                                "status": "COMPLETED",
                                "totalItems": 6,
                                "checkedItems": 6,
                                "progressPercent": 100,
                                "completedAt": "2026-10-30T08:12:00+09:00"
                            }
                        ]
                    }
                }
                """#
            )
        }
        defer { try? harness.tokenStore.clear() }

        let rounds = try await harness.service.fetchRounds(date: "2026-10-30")

        XCTAssertEqual(rounds.summary.progressPercent, 33)
        XCTAssertEqual(rounds.items.first?.status, .completed)
        let request = try XCTUnwrap(harness.requests.requests.first)
        XCTAssertEqual(request.url?.path, HGAPIPath.teamChecklistRounds)
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems,
                       [URLQueryItem(name: "date", value: "2026-10-30")])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer checklist-fixture-token")
    }

    func testFetchRoundPercentEncodesColonAndDecodesItems() async throws {
        let harness = try makeService { _ in
            (
                200,
                #"""
                {
                    "success": true,
                    "data": {
                        "date": "2026-10-30",
                        "teamId": "team_01",
                        "roundId": "08:00",
                        "startsAt": "2026-10-30T08:00:00+09:00",
                        "endsAt": "2026-10-30T10:00:00+09:00",
                        "status": "IN_PROGRESS",
                        "totalItems": 1,
                        "checkedItems": 0,
                        "progressPercent": 0,
                        "completedAt": null,
                        "items": [
                            {
                                "itemId": "item_01",
                                "text": "식수를 준비했나요?",
                                "sortOrder": 1,
                                "checked": false,
                                "checkedAt": null
                            }
                        ]
                    }
                }
                """#
            )
        }
        defer { try? harness.tokenStore.clear() }

        let round = try await harness.service.fetchRound(id: "08:00", date: "2026-10-30")

        XCTAssertEqual(round.items.first?.text, "식수를 준비했나요?")
        let request = try XCTUnwrap(harness.requests.requests.first)
        XCTAssertTrue(try XCTUnwrap(request.url?.absoluteString).contains("/rounds/08%3A00?date=2026-10-30"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer checklist-fixture-token")
    }

    func testEmptyRoundDoesNotBecomeCompletedAutomatically() async throws {
        let harness = try makeService { _ in
            (
                200,
                #"""
                {
                    "success": true,
                    "data": {
                        "date": "2026-10-30",
                        "teamId": "team_01",
                        "roundId": "08:00",
                        "startsAt": "2026-10-30T08:00:00+09:00",
                        "endsAt": "2026-10-30T10:00:00+09:00",
                        "status": "IN_PROGRESS",
                        "totalItems": 0,
                        "checkedItems": 0,
                        "progressPercent": 0,
                        "completedAt": null,
                        "items": []
                    }
                }
                """#
            )
        }
        defer { try? harness.tokenStore.clear() }

        let round = try await harness.service.fetchRound(id: "08:00", date: "2026-10-30")

        XCTAssertFalse(round.isComplete)
        XCTAssertEqual(round.status, .inProgress)
    }

    func testRoundItemUpdateRefetchesDetailAndRoundsAfterPut() async throws {
        let harness = try makeService { request in
            if request.httpMethod == "PUT" {
                return (
                    200,
                    #"""
                    {
                        "success": true,
                        "data": {
                            "date": "2026-10-30",
                            "roundId": "08:00",
                            "itemId": "item_01",
                            "checked": true,
                            "checkedAt": "2026-10-30T08:10:00+09:00"
                        }
                    }
                    """#
                )
            }
            if request.url?.path.contains("/rounds/08:00") == true {
                return (
                    200,
                    #"""
                    {
                        "success": true,
                        "data": {
                            "date": "2026-10-30",
                            "teamId": "team_01",
                            "roundId": "08:00",
                            "startsAt": "2026-10-30T08:00:00+09:00",
                            "endsAt": "2026-10-30T10:00:00+09:00",
                            "status": "IN_PROGRESS",
                            "totalItems": 1,
                            "checkedItems": 1,
                            "progressPercent": 100,
                            "completedAt": null,
                            "items": [
                                {
                                    "itemId": "item_01",
                                    "text": "식수를 준비했나요?",
                                    "sortOrder": 1,
                                    "checked": true,
                                    "checkedAt": "2026-10-30T08:10:00+09:00"
                                }
                            ]
                        }
                    }
                    """#
                )
            }
            return (
                200,
                #"""
                {
                    "success": true,
                    "data": {
                        "date": "2026-10-30",
                        "teamId": "team_01",
                        "summary": {
                            "totalRounds": 1,
                            "completedRounds": 0,
                            "missedRounds": 0,
                            "remainingRounds": 1,
                            "progressPercent": 0
                        },
                        "items": [
                            {
                                "roundId": "08:00",
                                "startsAt": "2026-10-30T08:00:00+09:00",
                                "endsAt": "2026-10-30T10:00:00+09:00",
                                "status": "IN_PROGRESS",
                                "totalItems": 1,
                                "checkedItems": 1,
                                "progressPercent": 100,
                                "completedAt": null
                            }
                        ]
                    }
                }
                """#
            )
        }
        defer { try? harness.tokenStore.clear() }

        let refreshed = try await harness.service.updateRoundItem(
            roundID: "08:00", itemID: "item_01", isChecked: true, date: "2026-10-30"
        )

        XCTAssertTrue(refreshed.round.items[0].checked)
        XCTAssertEqual(refreshed.rounds.items[0].checkedItems, 1)
        let requests = harness.requests.requests
        XCTAssertEqual(requests.map(\.httpMethod), ["PUT", "GET", "GET"])
        XCTAssertTrue(try XCTUnwrap(requests[0].url?.absoluteString).contains("/rounds/08%3A00/items/item_01"))
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer checklist-fixture-token")
        let body = try XCTUnwrap(requestBody(for: requests[0]))
        XCTAssertEqual(try JSONSerialization.jsonObject(with: body) as? [String: Bool], ["checked": true])
    }

    func testChecklistRoundServerErrorsKeepTheirDiagnosticCodesAndUserMeaning() {
        struct ErrorCase {
            let status: Int
            let code: String
            let expectedTitle: String
        }
        let cases = [
            ErrorCase(status: 400, code: "VALIDATION_ERROR", expectedTitle: "체크 요청을 확인해주세요"),
            ErrorCase(status: 403, code: "TEAM_MEMBERSHIP_REQUIRED", expectedTitle: "팀 권한을 확인해주세요"),
            ErrorCase(status: 404, code: "RESOURCE_NOT_FOUND", expectedTitle: "회차 정보를 찾을 수 없습니다"),
            ErrorCase(status: 409, code: "ROUND_NOT_OPEN", expectedTitle: "체크할 수 없는 회차입니다")
        ]

        for errorCase in cases {
            let error = HGAPIError.server(
                message: "server detail",
                statusCode: errorCase.status,
                serverCode: errorCase.code
            )
            let presentation = HGChecklistAPIErrorPresentation.make(from: error)
            XCTAssertEqual(presentation.title, errorCase.expectedTitle)
            XCTAssertEqual(
                presentation.diagnosticCode,
                "HTTP \(errorCase.status) · \(errorCase.code)"
            )
            XCTAssertNotEqual(presentation.message, "server detail")
        }
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
