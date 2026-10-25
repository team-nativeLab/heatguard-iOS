import Foundation
import Security
import XCTest
@testable import heatguard_iOS

final class AuthTokenAccessibilityTests: XCTestCase {
    func testSaveAndLoadRestrictExistingTokensToThisDevice() throws {
        let account = "token-accessibility-\(UUID().uuidString)"
        let store = HGAuthTokenStore(account: account)
        defer { try? store.clear() }

        try store.save("first-token")
        XCTAssertEqual(try accessibility(for: account), kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)

        let legacyToken = "legacy-token"
        let updateStatus = SecItemUpdate(
            query(for: account) as CFDictionary,
            [
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
                kSecValueData as String: Data(legacyToken.utf8)
            ] as CFDictionary
        )
        XCTAssertEqual(updateStatus, errSecSuccess)

        XCTAssertEqual(try store.load(), legacyToken)
        XCTAssertEqual(try accessibility(for: account), kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)

        try store.save("updated-token")
        XCTAssertEqual(try store.load(), "updated-token")
        XCTAssertEqual(try accessibility(for: account), kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    }

    private func accessibility(for account: String) throws -> String? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(
            query(for: account).merging([kSecReturnAttributes as String: true]) { _, new in new } as CFDictionary,
            &result
        )
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        let attributes = try XCTUnwrap(result as? [String: Any])
        return attributes[kSecAttrAccessible as String] as? String
    }

    private func query(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "aa.heatguard-iOS",
            kSecAttrAccount as String: account
        ]
    }
}
