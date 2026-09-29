import Foundation
import Security

struct HGAuthenticationService {
    private let client: HGAPIClient
    private let tokenStore: HGAuthTokenStore
    private let sessionState: HGSessionStateStore

    init(
        client: HGAPIClient = HGAPIClient(),
        tokenStore: HGAuthTokenStore = .shared,
        sessionState: HGSessionStateStore = .shared
    ) {
        self.client = client
        self.tokenStore = tokenStore
        self.sessionState = sessionState
    }

    func login(email: String, password: String) async throws -> TeamSession {
        let response: TeamLoginResponse = try await client.send(
            TeamLoginRequest(email: email, password: password),
            method: "POST",
            path: HGAPIPath.teamLogin
        )
        try tokenStore.save(response.accessToken)
        sessionState.markSignedIn()
        return TeamSession()
    }

    func restoreSession() async throws -> TeamSession? {
        guard !sessionState.isSignedOut, try tokenStore.load() != nil else { return nil }

        let _: TeamSessionResponse = try await client.get(
            path: HGAPIPath.teamMe,
            requiresAuthentication: true
        )
        return TeamSession()
    }

    func currentProfile() async throws -> HGTeamProfile {
        try await client.get(path: HGAPIPath.teamMe, requiresAuthentication: true)
    }

    func updateProfile(
        name: String,
        email: String,
        phone: String,
        version: Int?
    ) async throws -> HGTeamProfile {
        try await client.send(
            TeamProfileUpdateRequest(name: name, email: email, phone: phone, version: version),
            method: "PATCH",
            path: HGAPIPath.teamMe,
            requiresAuthentication: true
        )
    }

    func logout() async throws {
        try await client.sendVoid(method: "POST", path: HGAPIPath.teamLogout, requiresAuthentication: true)
        endLocalSession()
    }

    func endLocalSession() {
        sessionState.markSignedOut()
        try? tokenStore.clear()
    }

    func changePassword(currentPassword: String, newPassword: String) async throws {
        let _: PasswordChangeResponse = try await client.send(
            PasswordChangeRequest(currentPassword: currentPassword, newPassword: newPassword),
            method: "PUT",
            path: HGAPIPath.teamPassword,
            requiresAuthentication: true
        )
    }

    func withdraw(currentPassword: String, reason: String? = nil) async throws {
        try await client.sendVoid(
            WithdrawalRequest(currentPassword: currentPassword, reason: reason),
            method: "DELETE",
            path: HGAPIPath.teamProfile,
            requiresAuthentication: true
        )
        endLocalSession()
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

struct HGTeamProfile: Decodable, Equatable {
    let userID: String
    let name: String
    let email: String
    let phone: String?
    let role: String
    let teamID: String?
    let companyID: String?
    let companyName: String?
    let version: Int?

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case name, email, phone, role, version
        case teamID = "teamId"
        case companyID = "companyId"
        case companyName
    }
}

private struct PasswordChangeRequest: Encodable {
    let currentPassword: String
    let newPassword: String
}

private struct TeamProfileUpdateRequest: Encodable {
    let name: String
    let email: String
    let phone: String
    let version: Int?
}

private struct PasswordChangeResponse: Decodable {
    let changedAt: String?
}

private struct WithdrawalRequest: Encodable { let currentPassword: String; let reason: String? }

struct TeamSession: Equatable {}

final class HGAuthTokenStore {
    static let shared = HGAuthTokenStore()

    private let service = "aa.heatguard-iOS"
    private let account = "team-session-access-token"

    private init() {}

    func save(_ token: String) throws {
        let valueData = Data(token.utf8)
        let query = itemQuery
        let attributes = [kSecValueData as String: valueData]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw keychainError(operation: "저장", status: updateStatus)
        }

        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: valueData
        ]
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw keychainError(operation: "저장", status: status)
        }
    }

    func load() throws -> String? {
        let query = itemQuery.merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }
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
            throw keychainError(operation: "불러오기", status: status)
        }

        return token
    }

    func clear() throws { try delete() }

    private func delete() throws {
        let status = SecItemDelete(itemQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError(operation: "삭제", status: status)
        }
    }

    private var itemQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func keychainError(operation: String, status: OSStatus) -> HGAPIError {
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        return .keychain(message: "인증 정보를 \(operation)하지 못했습니다. \(detail)", status: status)
    }
}

final class HGSessionStateStore {
    static let shared = HGSessionStateStore()

    private let signedOutKey = "aa.heatguard-iOS.session-signed-out"
    private let userDefaults: UserDefaults

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var isSignedOut: Bool {
        userDefaults.bool(forKey: signedOutKey)
    }

    func markSignedIn() {
        userDefaults.removeObject(forKey: signedOutKey)
    }

    func markSignedOut() {
        userDefaults.set(true, forKey: signedOutKey)
    }
}
