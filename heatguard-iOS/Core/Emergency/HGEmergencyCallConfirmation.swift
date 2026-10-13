import Foundation

/// 사용자가 안내 창에서 호출을 확인한 뒤 실행합니다.
/// 진행 중인 호출은 재사용해 중복 알림을 만들지 않습니다.
@MainActor
enum HGEmergencyCallConfirmation {
    static func perform(
        currentCall: () async throws -> HGEmergencyCall?,
        createCall: () async throws -> String
    ) async throws -> HGEmergencyCall {
        if let call = try await currentCall() { return call }
        return HGEmergencyCall(id: try await createCall(), status: .active)
    }
}
