import Foundation

enum HGAPIPath {
    static let registrationEmailCodes = "/api/v1/auth/email-codes"
    static let appRegister = "/api/v1/auth/app/register"
    static let appLogin = "/api/v1/auth/app/login"
    static let appLogout = "/api/v1/auth/app/logout"
    static let appMe = "/api/v1/auth/app/me"
    static let appSites = "/api/v1/app/sites"
    static let appLinkClaim = "/api/v1/app/links/claim"
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
    static let teamNotifications = "/api/v1/team/notifications"

    static func teamChecklistItem(id: String) -> String { "\(teamChecklist)/items/\(id)" }
    static func teamRecord(id: String) -> String { "\(teamRecords)/\(id)" }
    static func teamEmergencyCall(id: String) -> String { "\(teamEmergencyCalls)/\(id)" }
    static func teamInquiry(id: String) -> String { "\(teamInquiries)/\(id)" }
    static func teamNotificationRead(id: String) -> String { "\(teamNotifications)/\(id)/read" }
    static func appSiteSelect(id: String) -> String { "\(appSites)/\(id)/select" }
    static func appSiteUnlink(id: String) -> String { "\(appSites)/\(id)/link" }
}
