import XCTest
@testable import heatguard_iOS

@MainActor
final class DateFormattingTests: XCTestCase {
    func testUTCDateCrossesMidnightInSeoul() {
        XCTAssertEqual(HGDateFormatting.day("2026-10-08T16:30:00Z"), "2026.10.09")
        XCTAssertEqual(HGDateFormatting.time("2026-10-08T16:30:00Z"), "01:30")
    }

    func testFractionalSecondsAndExplicitOffsetMatch() {
        XCTAssertEqual(HGDateFormatting.recordTimestamp("2026-10-08T16:30:00.123Z"), "2026.10.09 (금) 01:30")
        XCTAssertEqual(HGDateFormatting.recordTimestamp("2026-10-09T01:30:00+09:00"), "2026.10.09 (금) 01:30")
    }

    func testInvalidTimestampNeverLeaksIntoLayout() {
        XCTAssertEqual(HGDateFormatting.recordTimestamp("invalid-server-timestamp"), "시간 정보 없음")
        XCTAssertEqual(HGDateFormatting.time("invalid-server-timestamp"), "—")
        XCTAssertEqual(HGDateFormatting.day(""), "날짜 정보 없음")
    }

    func testSavedTimestampUses24HourKoreanFormat() throws {
        let date = try XCTUnwrap("2026-10-09T04:05:00Z".hgISO8601Date)
        XCTAssertEqual(HGDateFormatting.timestamp(date), "2026.10.09 13:05")
    }

    func testGroupingUsesSeoulDayBoundary() throws {
        let first = try XCTUnwrap("2026-10-08T15:00:00Z".hgISO8601Date)
        let second = try XCTUnwrap("2026-10-09T14:59:00Z".hgISO8601Date)
        XCTAssertTrue(HGDateFormatting.calendar.isDate(first, inSameDayAs: second))
    }
}
