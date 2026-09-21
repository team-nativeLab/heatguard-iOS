import Foundation
import Security

struct HGAuthenticationService {
    private let client: HGAPIClient
    private let tokenStore: HGAuthTokenStore

    init(
        client: HGAPIClient = HGAPIClient(),
        tokenStore: HGAuthTokenStore = .shared
    ) {
        self.client = client
        self.tokenStore = tokenStore
    }

    func register(_ request: SiteRegistrationRequest) async throws {
        let _: SiteRegistrationResponse = try await client.send(
            request,
            method: "POST",
            path: "/api/v1/auth/site/register"
        )
    }

    func login(email: String, password: String) async throws -> SiteSession {
        let response: SiteLoginResponse = try await client.send(
            SiteLoginRequest(email: email, password: password),
            method: "POST",
            path: "/api/v1/auth/site/login"
        )
        try tokenStore.save(response.accessToken)

        return SiteSession(
            userID: response.user.userID,
            name: response.user.name,
            siteID: response.siteID,
            expiresAt: response.expiresAt
        )
    }

    func logout() async throws {
        try await client.sendVoid(method: "POST", path: "/api/v1/auth/site/logout", requiresAuthentication: true)
        try tokenStore.clear()
    }
}

struct SiteRegistrationRequest: Encodable {
    let companyName: String
    let managerName: String
    let siteName: String
    let email: String
    let password: String
}

private struct SiteRegistrationResponse: Decodable {
    let userID: String
    let siteID: String
    let defaultTeamID: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case siteID = "siteId"
        case defaultTeamID = "defaultTeamId"
        case createdAt
    }
}

private struct SiteLoginRequest: Encodable {
    let email: String
    let password: String
}

private struct SiteLoginResponse: Decodable {
    let user: SiteUser
    let siteID: String
    let expiresAt: String
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case user
        case siteID = "siteId"
        case expiresAt
        case accessToken
    }
}

private struct SiteUser: Decodable {
    let userID: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case name
    }
}

struct SiteSession: Equatable {
    let userID: String
    let name: String
    let siteID: String
    let expiresAt: String
}

final class HGAuthTokenStore {
    static let shared = HGAuthTokenStore()

    private let service = "aa.heatguard-iOS"
    private let account = "site-access-token"

    private init() {}

    func save(_ token: String) throws {
        try delete()
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8)
        ]
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw HGAPIError.configuration("인증 정보를 저장하지 못했습니다.")
        }
    }

    func load() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard
            status == errSecSuccess,
            let data = result as? Data,
            let token = String(data: data, encoding: .utf8)
        else {
            throw HGAPIError.configuration("인증 정보를 불러오지 못했습니다.")
        }

        return token
    }

    func clear() throws { try delete() }

    private func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw HGAPIError.configuration("기존 인증 정보를 정리하지 못했습니다.")
        }
    }
}
