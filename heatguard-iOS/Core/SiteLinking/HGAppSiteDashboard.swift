import Foundation

struct HGAppSiteDashboard: Decodable {
    let summary: HGAppSiteDashboardSummary?
    let weather: HGAppSiteDashboardWeather?
    let heatLevel: Double?
    let recentRecords: [HGAppSiteDashboardRecord]?
    let activeEmergencyCalls: [HGAppSiteDashboardEmergencyCall]?
}

struct HGAppSiteDashboardSummary: Decodable {
    let todayRecordCount: Int?
    let activeEmergencyCount: Int?
}

struct HGAppSiteDashboardWeather: Decodable {
    let temperature: Double?
    let humidity: Double?
    let apparentTemperature: Double?
    let observedAt: String?
    let skyStatus: String?
}

struct HGAppSiteDashboardRecord: Decodable, Identifiable {
    let recordID: String
    let type: String?
    let measuredAt: String?
    let temperature: Double?
    let teamName: String?

    var id: String { recordID }

    enum CodingKeys: String, CodingKey {
        case recordID = "recordId"
        case type
        case measuredAt
        case temperature
        case teamName
    }
}

struct HGAppSiteDashboardEmergencyCall: Decodable, Identifiable {
    let callID: String
    let createdAt: String?

    var id: String { callID }

    enum CodingKeys: String, CodingKey {
        case callID = "callId"
        case createdAt
    }
}
