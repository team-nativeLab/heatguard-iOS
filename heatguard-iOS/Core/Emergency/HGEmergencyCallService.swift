import Foundation

struct HGEmergencyCallService {
    private let client: HGAPIClient

    init(client: HGAPIClient = HGAPIClient()) {
        self.client = client
    }

    func createCall(message: String? = nil) async throws -> String {
        let response: HGEmergencyCallResponse = try await client.send(
            HGEmergencyCallRequest(message: message, clientOccurredAt: ISO8601DateFormatter.heatGuard.string(from: .now)),
            method: "POST",
            path: HGAPIPath.teamEmergencyCalls,
            requiresAuthentication: true,
            headers: ["Idempotency-Key": UUID().uuidString]
        )

        guard let callID = response.callID, !callID.isEmpty else {
            throw HGEmergencyCallError.missingCallID
        }
        return callID
    }

    func updateCall(id: String, status: HGEmergencyCallStatus) async throws {
        try await client.sendVoid(
            HGEmergencyCallStatusRequest(status: status),
            method: "PATCH",
            path: HGAPIPath.teamEmergencyCall(id: id),
            requiresAuthentication: true
        )
    }

    func fetchCurrentCall() async throws -> HGEmergencyCall? {
        let response: HGEmergencyCallResponse = try await client.get(
            path: HGAPIPath.teamCurrentEmergencyCall,
            requiresAuthentication: true
        )

        guard response.status != .none, let callID = response.callID, !callID.isEmpty else {
            return nil
        }

        return HGEmergencyCall(id: callID, status: response.status)
    }
}

struct HGEmergencyCall: Equatable {
    let id: String
    let status: HGEmergencyCallStatus
}

enum HGEmergencyCallStatus: String, Codable {
    case none = "NONE"
    case active = "ACTIVE"
    case acknowledged = "ACKNOWLEDGED"
    case cancelled = "CANCELLED"
    case completed = "COMPLETED"

    var canCancel: Bool { self == .active }
}

enum HGEmergencyCallError: LocalizedError {
    case missingCallID

    var errorDescription: String? {
        switch self {
        case .missingCallID: "긴급 호출 식별자를 서버 응답에서 찾지 못했습니다."
        }
    }

    var diagnosticCode: String {
        switch self {
        case .missingCallID: "EMERGENCY_CALL_ID_MISSING"
        }
    }
}

private struct HGEmergencyCallRequest: Encodable {
    let message: String?
    let clientOccurredAt: String
}

private struct HGEmergencyCallStatusRequest: Encodable {
    let status: HGEmergencyCallStatus
}

private struct HGEmergencyCallResponse: Decodable {
    let callID: String?
    let status: HGEmergencyCallStatus

    enum CodingKeys: String, CodingKey { case callID = "callId", status }
}
