import XCTest
@testable import HeatGuardNotificationCore

final class NotificationRoutingTests: XCTestCase {
    private func notification(type: HGNotificationType, id: String? = "target") -> HGNotification {
        HGNotification(notificationID: "notification", title: "알림", resourceID: id,
                       createdAt: "2026-10-04T00:00:00Z", type: type, category: .notice, read: false)
    }
    func testRecordRoutesToItsResource() { XCTAssertEqual(notification(type: .recordCreated).destination, .record("target")) }
    func testInquiryRoutesToItsResource() { XCTAssertEqual(notification(type: .inquiryAnswered).destination, .inquiry("target")) }
    func testEmergencyRoutesToDetail() { XCTAssertEqual(notification(type: .emergencyAcknowledged).destination, .detail) }
    func testUnknownNoticeRoutesToDetail() { XCTAssertEqual(notification(type: .unknown("NOTICE_CREATED")).destination, .detail) }
    func testMissingTargetUsesDetail() {
        for type in [HGNotificationType.recordCreated, .inquiryAnswered, .emergencyAcknowledged] {
            for id in [nil, "", "  "] as [String?] { XCTAssertEqual(notification(type: type, id: id).destination, .detail) }
        }
    }
    func testReadStateDoesNotChangeDestination() {
        let unread = notification(type: .recordCreated)
        let read = HGNotification(notificationID: unread.id, title: unread.title, resourceID: unread.resourceID,
                                  createdAt: unread.createdAt, type: unread.type, category: unread.category, read: true)
        XCTAssertEqual(unread.destination, read.destination)
    }
    func testMatchingEmergencyShowsStatus() {
        let call = HGEmergencyCall(id: "target", status: .acknowledged)
        XCTAssertEqual(notification(type: .emergencyAcknowledged).relatedEmergencyCall(call), call)
    }
    func testOtherEmergencyIsNeverSubstituted() {
        XCTAssertNil(notification(type: .emergencyAcknowledged).relatedEmergencyCall(HGEmergencyCall(id: "another", status: .active)))
    }
    func testHistoricalEmergencyDoesNotCreateCall() {
        XCTAssertNil(notification(type: .emergencyAcknowledged).relatedEmergencyCall(nil))
    }
    func testOtherNotificationDoesNotResolveEmergency() {
        XCTAssertNil(notification(type: .recordCreated).relatedEmergencyCall(HGEmergencyCall(id: "target", status: .active)))
    }
    func testMissingResourceDecodesIntoFallback() throws {
        let value = try JSONDecoder().decode(HGNotification.self, from: Data(#"{"notificationId":"n","title":"알림","createdAt":"2026-10-04T00:00:00Z","type":"RECORD_CREATED","category":"RECORD","read":false}"#.utf8))
        XCTAssertEqual(value.destination, .detail)
    }
    func testAllWireTypesDecode() throws {
        for (raw, value) in [("RECORD_CREATED", HGNotificationType.recordCreated), ("INQUIRY_ANSWERED", .inquiryAnswered), ("EMERGENCY_ACKNOWLEDGED", .emergencyAcknowledged), ("FUTURE_EVENT", .unknown("FUTURE_EVENT"))] {
            XCTAssertEqual(try JSONDecoder().decode(HGNotificationType.self, from: JSONEncoder().encode(raw)), value)
        }
    }
}
