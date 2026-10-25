import Foundation
import XCTest
@testable import heatguard_iOS

final class AppSiteScopeTests: XCTestCase {
    func testSwitchingSiteSendsRequestScopeAndRejectsRevokedLink() async throws {
        let tokenStore = HGAuthTokenStore(account: "site-scope-\(UUID().uuidString)")
        try tokenStore.save("app-fixture-token")
        defer { try? tokenStore.clear() }
        var scopes: [String] = []
        AppSiteScopeURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/site/dashboard")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer app-fixture-token")
            let scope = try XCTUnwrap(request.value(forHTTPHeaderField: "X-Site-Id"))
            scopes.append(scope)
            let revoked = scopes.count == 3
            let data = revoked
                ? Data(#"{"success":false,"error":{"code":"FORBIDDEN","message":"unlinked"}}"#.utf8)
                : Data(#"""
                  {"success":true,"data":{"summary":{"todayRecordCount":2,"activeEmergencyCount":0},
                  "weather":null,"heatLevel":0,"recentRecords":[]}}
                  """#.utf8)
            let response = try XCTUnwrap(HTTPURLResponse(
                url: XCTUnwrap(request.url), statusCode: revoked ? 403 : 200,
                httpVersion: nil, headerFields: nil
            ))
            return (response, data)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AppSiteScopeURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
            AppSiteScopeURLProtocol.handler = nil
        }
        let service = HGAppSiteLinkingService(client: HGAPIClient(session: session, tokenStore: tokenStore))
        let first = try await service.dashboard(siteID: "site-a")
        XCTAssertEqual(first.summary.todayRecordCount, 2)
        _ = try await service.dashboard(siteID: "site-b")
        do {
            _ = try await service.dashboard(siteID: "site-a")
            XCTFail("A revoked site must not return cached dashboard data")
        } catch let error as HGAPIError {
            XCTAssertEqual(error.diagnosticCode, "HTTP 403 · FORBIDDEN")
        }
        XCTAssertEqual(scopes, ["site-a", "site-b", "site-a"])
    }
}

private final class AppSiteScopeURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    // URLProtocol requires class overrides.
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
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
