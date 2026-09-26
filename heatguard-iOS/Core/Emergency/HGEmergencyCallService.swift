import Foundation

struct HGEmergencyCallService {
    private let client: HGAPIClient

    init(client: HGAPIClient = HGAPIClient()) {
        self.client = client
    }

    func createCall(message: String? = nil) async throws {
        let _: HGEmergencyCallResponse = try await client.send(
            HGEmergencyCallRequest(message: message, clientOccurredAt: ISO8601DateFormatter().string(from: .now)),
            method: "POST",
            path: "/api/v1/team/emergency-calls",
            requiresAuthentication: true,
            headers: ["Idempotency-Key": UUID().uuidString]
        )
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
