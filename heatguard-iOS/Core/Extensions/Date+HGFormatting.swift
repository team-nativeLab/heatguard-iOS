import Foundation

extension ISO8601DateFormatter {
    static let heatGuard = ISO8601DateFormatter()
}

extension String {
    var hgISO8601Date: Date? { ISO8601DateFormatter.heatGuard.date(from: self) }
}
