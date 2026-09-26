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

    func login(email: String, password: String) async throws -> TeamSession {
        let response: TeamLoginResponse = try await client.send(
            TeamLoginRequest(email: email, password: password),
            method: "POST",
            path: "/api/v1/auth/team/login"
        )
        try tokenStore.save(response.accessToken)
        return TeamSession()
    }

    func restoreSession() async throws -> TeamSession? {
        guard try tokenStore.load() != nil else { return nil }

        let _: TeamSessionResponse = try await client.get(
            path: "/api/v1/auth/team/me",
            requiresAuthentication: true
        )
        return TeamSession()
    }

    func logout() async throws {
        try await client.sendVoid(method: "POST", path: "/api/v1/auth/team/logout", requiresAuthentication: true)
        try tokenStore.clear()
    }

    func endLocalSession() throws {
        try tokenStore.clear()
    }
}

private struct TeamLoginRequest: Encodable {
    let email: String
    let password: String
}

private struct TeamLoginResponse: Decodable {
    let accessToken: String

    private enum CodingKeys: String, CodingKey {
        case accessToken
        case token
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken) {
            self.accessToken = accessToken
        } else if let token = try container.decodeIfPresent(String.self, forKey: .token) {
            self.accessToken = token
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.accessToken,
                .init(codingPath: decoder.codingPath, debugDescription: "로그인 토큰이 없습니다.")
            )
        }
    }
}

private struct TeamSessionResponse: Decodable {}

struct TeamSession: Equatable {}

final class HGAuthTokenStore {
    static let shared = HGAuthTokenStore()

    private let service = "aa.heatguard-iOS"
    private let account = "team-session-access-token"

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
