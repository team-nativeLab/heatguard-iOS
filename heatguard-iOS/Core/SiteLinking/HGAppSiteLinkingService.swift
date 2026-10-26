import Foundation

struct HGAppSiteLinkingService {
    private let client: HGAPIClient
    private let tokenStore: HGAuthTokenStore

    init(client: HGAPIClient? = nil) {
        let tokenStore = HGAuthTokenStore(account: "app-session-access-token")
        self.tokenStore = tokenStore
        self.client = client ?? HGAPIClient(tokenStore: tokenStore)
    }

    func requestEmailCode(email: String) async throws {
        let _: HGAppEmailCodeResponse = try await client.send(
            HGAppEmailCodeRequest(email: email),
            method: "POST",
            path: HGAPIPath.registrationEmailCodes
        )
    }

    func register(email: String, password: String, verificationCode: String) async throws {
        try await client.sendVoid(
            HGAppRegisterRequest(
                email: email,
                password: password,
                confirmPassword: password,
                verificationCode: verificationCode
            ),
            method: "POST",
            path: HGAPIPath.appRegister
        )
    }

    func login(email: String, password: String) async throws {
        let response: HGAppLoginResponse = try await client.send(
            HGAppLoginRequest(email: email, password: password),
            method: "POST",
            path: HGAPIPath.appLogin
        )
        try tokenStore.save(response.accessToken)
    }

    func restoreSession() async throws -> Bool {
        guard try tokenStore.load() != nil else { return false }
        let _: HGAppAccountProfile = try await client.get(path: HGAPIPath.appMe, requiresAuthentication: true)
        return true
    }

    func logout() async {
        defer { try? tokenStore.clear() }
        try? await client.sendVoid(method: "POST", path: HGAPIPath.appLogout, requiresAuthentication: true)
    }

    func claim(token: String, managerPhone: String) async throws -> HGAppSite {
        let normalizedPhone = managerPhone.filter(\.isNumber)
        let nationalPhone: String
        if normalizedPhone.hasPrefix("82") {
            nationalPhone = "0" + String(normalizedPhone.dropFirst(2))
        } else if !normalizedPhone.hasPrefix("0"), (9...10).contains(normalizedPhone.count) {
            nationalPhone = "0" + normalizedPhone
        } else {
            nationalPhone = normalizedPhone
        }
        return try await client.send(
            HGAppLinkClaimRequest(token: token, managerPhone: String(nationalPhone)),
            method: "POST",
            path: HGAPIPath.appLinkClaim,
            requiresAuthentication: true
        )
    }

    func fetchSites() async throws -> [HGAppSite] {
        let response: HGAppSitesResponse = try await client.get(
            path: HGAPIPath.appSites,
            requiresAuthentication: true
        )
        return response.items
    }

    func fetchDashboard(siteID: String) async throws -> HGAppSiteDashboard {
        try await client.get(
            path: HGAPIPath.siteDashboard,
            requiresAuthentication: true,
            headers: ["X-Site-Id": siteID]
        )
    }

    func select(siteID: String) async throws -> HGAppSiteSelection {
        try await client.send(
            method: "POST",
            path: HGAPIPath.appSiteSelect(id: siteID),
            requiresAuthentication: true
        )
    }

    func unlink(siteID: String) async throws {
        try await client.sendVoid(method: "DELETE", path: HGAPIPath.appSiteUnlink(id: siteID), requiresAuthentication: true)
    }
}

struct HGAppSite: Decodable, Identifiable, Equatable {
    let siteID: String
    let siteName: String
    let managerName: String?
    let linkedAt: String?

    var id: String { siteID }

    enum CodingKeys: String, CodingKey {
        case siteID = "siteId"
        case siteName
        case managerName
        case linkedAt
    }
}

struct HGAppSiteSelection: Decodable {
    let siteID: String
    let siteName: String

    enum CodingKeys: String, CodingKey { case siteID = "siteId", siteName }
}

private struct HGAppEmailCodeRequest: Encodable { let email: String }
private struct HGAppEmailCodeResponse: Decodable { let expiresAt: String }
private struct HGAppRegisterRequest: Encodable {
    let email: String
    let password: String
    let confirmPassword: String
    let verificationCode: String
}
private struct HGAppLoginRequest: Encodable { let email: String; let password: String }
private struct HGAppLoginResponse: Decodable { let accessToken: String }
private struct HGAppAccountProfile: Decodable { let userId: String; let email: String }
private struct HGAppLinkClaimRequest: Encodable { let token: String; let managerPhone: String }
private struct HGAppSitesResponse: Decodable { let items: [HGAppSite] }
