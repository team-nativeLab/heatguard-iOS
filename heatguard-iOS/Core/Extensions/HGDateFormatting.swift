import Foundation

/// 한국 현장 기록의 표시 기준을 기기 언어·시간대와 분리합니다.
enum HGDateFormatting {
    static let locale = Locale(identifier: "ko_KR")
    static let timeZone = TimeZone(identifier: "Asia/Seoul") ?? TimeZone(secondsFromGMT: 9 * 3600) ?? .gmt

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = timeZone
        return calendar
    }

    static func string(from date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    static func timestamp(_ date: Date) -> String {
        string(from: date, format: "yyyy.MM.dd HH:mm")
    }

    static func recordTimestamp(_ value: String) -> String {
        value.hgISO8601Date.map { string(from: $0, format: "yyyy.MM.dd (E) HH:mm") }
            ?? "시간 정보 없음"
    }

    static func time(_ value: String) -> String {
        value.hgISO8601Date.map { string(from: $0, format: "HH:mm") } ?? "—"
    }

    static func day(_ value: String) -> String {
        value.hgISO8601Date.map { string(from: $0, format: "yyyy.MM.dd") } ?? "날짜 정보 없음"
    }
}
