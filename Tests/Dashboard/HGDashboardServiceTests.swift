import Foundation
import XCTest
@testable import heatguard_iOS

@MainActor
final class HGDashboardServiceTests: XCTestCase {
    func testFetchesAuthenticatedTeamDashboardAndUsesWeatherFields() async throws {
        let (service, requestLog) = try makeService(data: [
            "success": true,
            "data": [
                "weather": [
                    "temperature": 34.6,
                    "humidity": 72.0,
                    "heatLevel": 3.0,
                    "skyStatus": "CLEAR",
                    "observedAt": "2026-11-20T10:00:00+09:00"
                ],
                "checkTimes": ["08:00"],
                "checklistSummary": ["total": 2, "completed": 1],
                "unreadNotificationCount": 3
            ]
        ])

        let dashboard = try await service.fetchHomeDashboard()
        let request = try XCTUnwrap(requestLog.requests.first)
        XCTAssertEqual(request.url?.path, HGAPIPath.teamHome)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")
        XCTAssertEqual(dashboard.weather.temperature, 34.6)
        XCTAssertEqual(dashboard.weather.humidity, 72)
        XCTAssertEqual(dashboard.weather.heatLevel, 3)
        XCTAssertEqual(dashboard.weather.weatherStatusText, "맑음")
        XCTAssertEqual(dashboard.weather.heatLevelTitle, "폭염 위험 단계")
        XCTAssertEqual(dashboard.checklist.checkedCount, 1)
        XCTAssertEqual(dashboard.unreadNotificationCount, 3)
    }

    func testMissingWeatherFieldsRemainUnavailableInsteadOfFailingDashboardDecode() async throws {
        let (service, _) = try makeService(data: ["success": true, "data": [:]])
        let dashboard = try await service.fetchHomeDashboard()

        XCTAssertNil(dashboard.weather.temperature)
        XCTAssertEqual(dashboard.weather.temperatureText, "—")
        XCTAssertEqual(dashboard.weather.weatherStatusText, "정보 없음")
    }

    private func makeService(data: [String: Any]) throws -> (HGDashboardService, DashboardRequestLog) {
        let tokenStore = HGAuthTokenStore(account: "dashboard-fixture-\(UUID().uuidString)")
        try tokenStore.save("fixture-token")
        addTeardownBlock { try? tokenStore.clear() }

        let body = try JSONSerialization.data(withJSONObject: data)
        let log = DashboardRequestLog()
        DashboardFixtureURLProtocol.handler = { request in
            log.append(request)
            let url = try XCTUnwrap(request.url)
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
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DashboardFixtureURLProtocol.self]
        let session = URLSession(configuration: configuration)
        addTeardownBlock {
            session.invalidateAndCancel()
            DashboardFixtureURLProtocol.handler = nil
        }
        return (HGDashboardService(client: HGAPIClient(session: session, tokenStore: tokenStore)), log)
    }
}

private final class DashboardRequestLog: @unchecked Sendable {
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

private final class DashboardFixtureURLProtocol: URLProtocol {
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
