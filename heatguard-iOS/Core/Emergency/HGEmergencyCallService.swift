import Foundation

struct HGEmergencyCallService {
    private let client: HGAPIClient
    private let teamTokenStore: HGTeamAccessTokenStore

    init(client: HGAPIClient = HGAPIClient(), teamTokenStore: HGTeamAccessTokenStore = .shared) {
        self.client = client
        self.teamTokenStore = teamTokenStore
    }

    func createCall(message: String? = nil) async throws -> HGEmergencyCall {
        let token = try teamToken()
        let response: HGEmergencyCallResponse = try await client.send(
            HGEmergencyCallRequest(message: message, clientOccurredAt: ISO8601DateFormatter().string(from: .now)),
            method: "POST",
            path: "/api/v1/t/\(token)/emergency-calls",
            headers: ["Idempotency-Key": UUID().uuidString]
        )
        return HGEmergencyCall(response: response)
    }

    func currentCall() async throws -> HGEmergencyCall? {
        let token = try teamToken()
        let response: HGEmergencyCallResponse = try await client.get(path: "/api/v1/t/\(token)/emergency-calls/current")
        return response.status == "NONE" ? nil : HGEmergencyCall(response: response)
    }

    private func teamToken() throws -> String {
        guard let token = try teamTokenStore.load() else { throw HGAPIError.authenticationRequired }
        return token
    }
}

struct HGEmergencyCall: Equatable {
    let callID: String?
    let status: String

    fileprivate init(response: HGEmergencyCallResponse) {
        callID = response.callID
        status = response.status
    }
}

private struct HGEmergencyCallRequest: Encodable {
    let message: String?
    let clientOccurredAt: String
}

private struct HGEmergencyCallResponse: Decodable {
    let callID: String?
    let status: String

    enum CodingKeys: String, CodingKey { case callID = "callId", status }
}
