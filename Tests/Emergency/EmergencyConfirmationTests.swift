import XCTest
@testable import heatguard_iOS

@MainActor
final class EmergencyConfirmationTests: XCTestCase {
    func testConfirmedNewCallIsCreatedOnce() async throws {
        var creates = 0
        let call = try await HGEmergencyCallConfirmation.perform(currentCall: { nil }, createCall: {
            creates += 1
            return "new"
        })
        XCTAssertEqual(call, HGEmergencyCall(id: "new", status: .active))
        XCTAssertEqual(creates, 1)
    }

    func testConfirmedExistingCallDoesNotCreateDuplicate() async throws {
        for status in [HGEmergencyCallStatus.active, .acknowledged] {
            var creates = 0
            let existing = HGEmergencyCall(id: "existing", status: status)
            let call = try await HGEmergencyCallConfirmation.perform(currentCall: { existing }, createCall: {
                creates += 1
                return "duplicate"
            })
            XCTAssertEqual(call, existing)
            XCTAssertEqual(creates, 0)
        }
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
