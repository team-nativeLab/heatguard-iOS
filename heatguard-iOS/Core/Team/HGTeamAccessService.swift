import Foundation

struct HGTeamAccessService {
    private let client: HGAPIClient
    private let teamTokenStore: HGTeamAccessTokenStore

    init(
        client: HGAPIClient = HGAPIClient(),
        teamTokenStore: HGTeamAccessTokenStore = .shared
    ) {
        self.client = client
        self.teamTokenStore = teamTokenStore
    }

    func token() async throws -> String {
        if let token = try teamTokenStore.load() {
            return token
        }

        let teams: HGTeamPageResponse = try await client.get(
            path: "/api/v1/site/teams",
            requiresAuthentication: true
        )
        guard let defaultTeam = teams.items.first else {
            throw HGRecordUploadError.teamUnavailable
        }

        let rotation: HGTeamTokenRotationResponse = try await client.send(
            HGTeamTokenRotationRequest(graceSeconds: 0),
            method: "POST",
            path: "/api/v1/site/teams/\(defaultTeam.teamID)/token-rotation",
            requiresAuthentication: true
        )
        guard let token = URL(string: rotation.accessURL)?.lastPathComponent, !token.isEmpty else {
            throw HGRecordUploadError.teamUnavailable
        }
        try teamTokenStore.save(token)
        return token
    }
}

private struct HGTeamPageResponse: Decodable {
    let items: [HGTeam]
}

private struct HGTeam: Decodable {
    let teamID: String

    enum CodingKeys: String, CodingKey {
        case teamID = "teamId"
    }
}

private struct HGTeamTokenRotationRequest: Encodable {
    let graceSeconds: Int
}

private struct HGTeamTokenRotationResponse: Decodable {
    let accessURL: String

    enum CodingKeys: String, CodingKey {
        case accessURL = "accessUrl"
    }
}
