import XCTest
@testable import heatguard_iOS

@MainActor
final class EmergencyConfirmationTests: XCTestCase {
    func testOnlyActiveEmergencyCallsCanBeCancelled() {
        XCTAssertTrue(HGEmergencyCallStatus.active.canCancel)
        XCTAssertFalse(HGEmergencyCallStatus.acknowledged.canCancel)
        XCTAssertFalse(HGEmergencyCallStatus.cancelled.canCancel)
        XCTAssertFalse(HGEmergencyCallStatus.completed.canCancel)
    }

    func testConfirmedNewCallIsCreatedOnce() async throws {
        var creates = 0
        let call = try await HGEmergencyCallConfirmation.perform(currentCall: { nil }, createCall: {
            creates += 1
            return "new"
        })
        XCTAssertEqual(call, HGEmergencyCall(id: "new", status: .active))
        XCTAssertEqual(creates, 1)
    }

    func testConfirmedActiveCallDoesNotCreateDuplicate() async throws {
        var creates = 0
        let existing = HGEmergencyCall(id: "existing", status: .active)
        let call = try await HGEmergencyCallConfirmation.perform(currentCall: { existing }, createCall: {
            creates += 1
            return "duplicate"
        })
        XCTAssertEqual(call, existing)
        XCTAssertEqual(creates, 0)
    }

    func testConfirmedAcknowledgedCallCreatesNewCall() async throws {
        var creates = 0
        let acknowledged = HGEmergencyCall(id: "acknowledged", status: .acknowledged)
        let call = try await HGEmergencyCallConfirmation.perform(currentCall: { acknowledged }, createCall: {
            creates += 1
            return "new"
        })
        XCTAssertEqual(call, HGEmergencyCall(id: "new", status: .active))
        XCTAssertEqual(creates, 1)
    }

    func testFailedLookupNeverCreatesCall() async {
        var creates = 0
        do {
            _ = try await HGEmergencyCallConfirmation.perform(currentCall: { throw URLError(.notConnectedToInternet) }, createCall: {
                creates += 1
                return "unexpected"
            })
            XCTFail("조회 실패를 전달해야 합니다")
        } catch {
            XCTAssertEqual(creates, 0)
        }
    }
}
