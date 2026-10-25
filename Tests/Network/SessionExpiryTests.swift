import Foundation
import UIKit
import XCTest
@testable import heatguard_iOS

@MainActor
final class SessionExpiryTests: XCTestCase {
    func testExpiredSessionNotifiesAppWithoutPasswordRelogin() async throws {
        try await check(status: 401, code: "UNAUTHORIZED", expectedNotifications: 1)
    }

    func testInvalidCurrentPasswordDoesNotEndSession() async throws {
        try await check(status: 401, code: "INVALID_CREDENTIALS", expectedNotifications: 0)
    }

    func testPermissionDeniedDoesNotEndSession() async throws {
        try await check(status: 403, code: "FORBIDDEN", expectedNotifications: 0)
    }

    func testDisabledAccountEndsSession() async throws {
        try await check(status: 403, code: "ACCOUNT_DISABLED", expectedNotifications: 1)
    }

    func testLoginFailureDoesNotExpireExistingSession() async throws {
        try await check(status: 401, code: "UNAUTHORIZED", authenticated: false, expectedNotifications: 0)
    }

    func testOldAccountResponseCannotExpireNewAccount() async throws {
        try await check(status: 401, code: "UNAUTHORIZED", switchAccount: true, expectedNotifications: 0)
    }

    func testLogoutClearsDraftEvenWhenExpiryAlreadyClearedAccountIdentity() async throws {
        let suite = "logout-fixture-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = HGSessionStateStore(userDefaults: defaults)
        state.setUserID(suite)
        let draftStore = HGRecordDraftStore(ownerID: suite)
        defer { try? draftStore.clear() }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in }
        try draftStore.save(draft: HGRecordDraft(type: .work, memo: "fixture"), images: [image])
        let tokenStore = HGAuthTokenStore(account: suite)
        try tokenStore.save("fixture-token")
        defer { try? tokenStore.clear() }
        let center = NotificationCenter()
        let observer = center.addObserver(forName: .hgSessionExpired, object: nil, queue: nil) { _ in
            state.markSignedOut()
        }
        defer { center.removeObserver(observer) }
        SessionExpiryURLProtocol.handler = { request in
            let data = Data(#"{"success":false,"error":{"code":"UNAUTHORIZED"}}"#.utf8)
            return (try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: 401, httpVersion: nil, headerFields: nil)), data)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SessionExpiryURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
            SessionExpiryURLProtocol.handler = nil
        }
        let client = HGAPIClient(session: session, tokenStore: tokenStore, notificationCenter: center)
        let authentication = HGAuthenticationService(client: client, tokenStore: tokenStore, sessionState: state)
        do {
            try await authentication.logout()
            XCTFail("fixture should reject expired credentials")
        } catch let error as HGAPIError {
            XCTAssertEqual(error.diagnosticCode, "HTTP 401 · UNAUTHORIZED")
        }
        XCTAssertTrue(state.isSignedOut)
        XCTAssertNil(try tokenStore.load())
        XCTAssertNil(try draftStore.load())
    }

    private func check(
        status: Int,
        code: String,
        authenticated: Bool = true,
        switchAccount: Bool = false,
        expectedNotifications: Int
    ) async throws {
        let tokenStore = HGAuthTokenStore(account: "expiry-fixture-\(UUID().uuidString)")
        try tokenStore.save("old-fixture-token")
        defer { try? tokenStore.clear() }
        let center = NotificationCenter()
        let notifications = expectation(description: "session expired")
        notifications.isInverted = expectedNotifications == 0
        let observer = center.addObserver(forName: .hgSessionExpired, object: nil, queue: nil) { notification in
            XCTAssertEqual(notification.object as? String, "old-fixture-token")
            XCTAssertTrue(Thread.isMainThread)
            notifications.fulfill()
        }
        defer { center.removeObserver(observer) }
        let requests = expectation(description: "exactly one request; no password recovery")
        requests.assertForOverFulfill = true
        SessionExpiryURLProtocol.handler = { request in
            requests.fulfill()
            if authenticated {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer old-fixture-token")
            }
            if switchAccount { try tokenStore.save("new-fixture-token") }
            let data = try JSONSerialization.data(withJSONObject: [
                "success": false, "error": ["code": code, "message": "fixture"]
            ])
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: XCTUnwrap(request.url),
                    statusCode: status,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, data)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SessionExpiryURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
            SessionExpiryURLProtocol.handler = nil
        }
        let client = HGAPIClient(session: session, tokenStore: tokenStore, notificationCenter: center)
        do {
            let _: HGTeamProfile = try await client.get(path: HGAPIPath.teamMe, requiresAuthentication: authenticated)
            XCTFail("fixture should return a server error")
        } catch let error as HGAPIError {
            XCTAssertEqual(error.diagnosticCode, "HTTP \(status) · \(code)")
        }
        await fulfillment(of: [requests, notifications], timeout: expectedNotifications == 0 ? 0.1 : 1)
        XCTAssertEqual(try tokenStore.load(), switchAccount ? "new-fixture-token" : "old-fixture-token")
    }
}

private final class SessionExpiryURLProtocol: URLProtocol {
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
