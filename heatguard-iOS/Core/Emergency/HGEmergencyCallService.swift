import Foundation

struct HGEmergencyCallService {
    private let client: HGAPIClient

    init(client: HGAPIClient = HGAPIClient()) {
        self.client = client
    }

    func createCall(message: String? = nil) async throws -> HGEmergencyCall {
        let response: HGEmergencyCallResponse = try await client.send(
            HGEmergencyCallRequest(message: message, clientOccurredAt: ISO8601DateFormatter().string(from: .now)),
            method: "POST",
            path: "/api/v1/team/emergency-calls",
            requiresAuthentication: true,
            headers: ["Idempotency-Key": UUID().uuidString]
        )
        return HGEmergencyCall(response: response)
    }

    func currentCall() async throws -> HGEmergencyCall? {
        let response: HGEmergencyCallResponse = try await client.get(
            path: "/api/v1/team/emergency-calls/current",
            requiresAuthentication: true
        )
        return response.status == "NONE" ? nil : HGEmergencyCall(response: response)
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
