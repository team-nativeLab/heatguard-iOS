import Foundation

extension ISO8601DateFormatter {
    static let heatGuard = ISO8601DateFormatter()
    static let heatGuardWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension String {
    var hgISO8601Date: Date? {
        ISO8601DateFormatter.heatGuardWithFractionalSeconds.date(from: self)
            ?? ISO8601DateFormatter.heatGuard.date(from: self)
    }
}
