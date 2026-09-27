import Foundation

enum HGAPIPath {
    static let teamLogin = "/api/v1/auth/team/login"
    static let teamMe = "/api/v1/auth/team/me"
    static let teamLogout = "/api/v1/auth/team/logout"
    static let teamPassword = "/api/v1/auth/team/password"
    static let teamProfile = "/api/v1/team/profile"
    static let teamHome = "/api/v1/team"
    static let teamChecklist = "/api/v1/team/checklist"
    static let teamUploads = "/api/v1/team/uploads"
    static let teamRecords = "/api/v1/team/records"
    static let teamEmergencyCalls = "/api/v1/team/emergency-calls"
    static let teamCurrentEmergencyCall = "\(teamEmergencyCalls)/current"
    static let teamInquiries = "/api/v1/team/inquiries"

    static func teamChecklistItem(id: String) -> String { "\(teamChecklist)/items/\(id)" }
    static func teamRecord(id: String) -> String { "\(teamRecords)/\(id)" }
    static func teamEmergencyCall(id: String) -> String { "\(teamEmergencyCalls)/\(id)" }
    static func teamInquiry(id: String) -> String { "\(teamInquiries)/\(id)" }
}
