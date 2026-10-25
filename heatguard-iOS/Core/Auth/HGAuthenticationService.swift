import Foundation
import Security

struct HGAuthenticationService {
    private let client: HGAPIClient
    private let tokenStore: HGAuthTokenStore
    private let credentialStore: HGAuthCredentialStore
    private let sessionState: HGSessionStateStore

    init(
        client: HGAPIClient = HGAPIClient(),
        tokenStore: HGAuthTokenStore = .shared,
        credentialStore: HGAuthCredentialStore = .shared,
        sessionState: HGSessionStateStore = .shared
    ) {
        self.client = client
        self.tokenStore = tokenStore
        self.credentialStore = credentialStore
        self.sessionState = sessionState
    }

    func login(email: String, password: String) async throws -> TeamSession {
        let response: TeamLoginResponse = try await client.send(
            TeamLoginRequest(email: email, password: password),
            method: "POST",
            path: HGAPIPath.teamLogin
        )
        try tokenStore.save(response.accessToken)
        // Passwords from the old test-account recovery path must not survive login.
        try credentialStore.clear()
        sessionState.markSignedIn()
        return TeamSession()
    }

    func requestRegistrationCode(email: String) async throws {
        try await client.sendVoid(
            TeamEmailCodeRequest(email: email),
            method: "POST",
            path: HGAPIPath.teamEmailCodes
        )
    }

    func register(email: String, password: String, verificationCode: String) async throws {
        try await client.sendVoid(
            TeamRegisterRequest(
                email: email,
                password: password,
                confirmPassword: password,
                verificationCode: verificationCode
            ),
            method: "POST",
            path: HGAPIPath.teamRegister
        )
    }

    func acceptInvitation(token: String) async throws {
        let _: TeamInvitationAcceptance = try await client.send(
            TeamInvitationAcceptRequest(token: token),
            method: "POST",
            path: HGAPIPath.teamInvitationAccept,
            requiresAuthentication: true
        )
    }

    func memberships() async throws -> HGTeamMemberships {
        try await client.get(path: HGAPIPath.teamMemberships, requiresAuthentication: true)
    }

    func selectMembership(teamID: String) async throws {
        try await client.sendVoid(
            method: "POST",
            path: HGAPIPath.teamMembershipSelect(id: teamID),
            requiresAuthentication: true
        )
    }

    func leaveMembership(teamID: String) async throws {
        try await client.sendVoid(
            method: "DELETE",
            path: HGAPIPath.teamMembershipLeave(id: teamID),
            requiresAuthentication: true
        )
    }

    func restoreSession() async throws -> TeamSession? {
        try credentialStore.clear()
        guard !sessionState.isSignedOut else { return nil }

        guard try tokenStore.load() != nil else {
            return nil
        }

        _ = try await currentProfile()
        return TeamSession()
    }

    func currentProfile() async throws -> HGTeamProfile {
        let profile: HGTeamProfile = try await client.get(path: HGAPIPath.teamMe, requiresAuthentication: true)
        sessionState.setUserID(profile.userID)
        try HGRecordDraftStore(ownerID: profile.userID).clearLegacyDraft()
        return profile
    }

    func updateProfile(
        name: String,
        email: String?,
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
        let draftStore = HGRecordDraftStore(ownerID: sessionState.userID)
        defer {
            // A 401 may already have reset session identity before this returns.
            try? draftStore.clear()
            endLocalSession()
        }
        try await client.sendVoid(method: "POST", path: HGAPIPath.teamLogout, requiresAuthentication: true)
    }

    func endLocalSession(clearDraft: Bool = true) {
        if clearDraft {
            try? HGRecordDraftStore(ownerID: sessionState.userID).clear()
        }
        try? HGRecordDraftStore().clearLegacyDraft()
        sessionState.markSignedOut()
        try? tokenStore.clear()
        try? credentialStore.clear()
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

private struct TeamEmailCodeRequest: Encodable { let email: String }

private struct TeamRegisterRequest: Encodable {
    let email: String
    let password: String
    let confirmPassword: String
    let verificationCode: String
}

private struct TeamInvitationAcceptRequest: Encodable { let token: String }

private struct TeamInvitationAcceptance: Decodable {
    let userID: String?
    let teamID: String?
    let siteID: String?

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case teamID = "teamId"
        case siteID = "siteId"
    }
}

struct HGTeamMemberships: Decodable {
    let items: [HGTeamMembership]
    let selectedTeamID: String?

    enum CodingKeys: String, CodingKey {
        case items
        case selectedTeamID = "selectedTeamId"
    }
}

struct HGTeamMembership: Decodable, Identifiable, Equatable {
    let teamID: String
    let teamName: String
    let siteID: String?
    let siteName: String?
    let companyID: String?

    var id: String { teamID }
    var displayName: String { siteName ?? teamName }

    enum CodingKeys: String, CodingKey {
        case teamID = "teamId"
        case teamName
        case siteID = "siteId"
        case siteName
        case companyID = "companyId"
    }
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
    let email: String?
    let phone: String
    let version: Int?
}

private struct PasswordChangeResponse: Decodable {
    let changedAt: String?
}

private struct WithdrawalRequest: Encodable { let currentPassword: String; let reason: String? }

struct TeamSession: Equatable {}

struct HGLoginCredentials: Codable {
    let email: String
    let password: String
}

final class HGAuthCredentialStore {
    static let shared = HGAuthCredentialStore()

    private let service = "aa.heatguard-iOS"
    private let account = "team-test-login-credentials"

    private init() {}

    func save(email: String, password: String) throws {
        let data = try JSONEncoder().encode(HGLoginCredentials(email: email, password: password))
        let updateStatus = SecItemUpdate(itemQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw keychainError(operation: "저장", status: updateStatus)
        }

        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw keychainError(operation: "저장", status: status)
        }
    }

    func load() throws -> HGLoginCredentials? {
        let query = itemQuery.merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw keychainError(operation: "불러오기", status: status)
        }
        return try JSONDecoder().decode(HGLoginCredentials.self, from: data)
    }

    func clear() throws {
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
        return .keychain(message: "로그인 정보를 \(operation)하지 못했습니다. \(detail)", status: status)
    }
}

final class HGAuthTokenStore {
    static let shared = HGAuthTokenStore()

    private let service = "aa.heatguard-iOS"
    private let account: String

    init(account: String = "team-session-access-token") {
        self.account = account
    }

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
    private let userIDKey = "aa.heatguard-iOS.session-user-id"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var isSignedOut: Bool {
        userDefaults.bool(forKey: signedOutKey)
    }

    func markSignedIn() {
        userDefaults.removeObject(forKey: userIDKey)
        userDefaults.removeObject(forKey: signedOutKey)
    }

    var userID: String? { userDefaults.string(forKey: userIDKey) }

    func setUserID(_ userID: String) {
        userDefaults.set(userID, forKey: userIDKey)
    }

    func markSignedOut() {
        userDefaults.removeObject(forKey: userIDKey)
        userDefaults.set(true, forKey: signedOutKey)
    }
}
