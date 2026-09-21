import Foundation

struct HGDashboardService {
    private let client: HGAPIClient
    private let teamAccessService: HGTeamAccessService

    init(
        client: HGAPIClient = HGAPIClient(),
        teamAccessService: HGTeamAccessService = HGTeamAccessService()
    ) {
        self.client = client
        self.teamAccessService = teamAccessService
    }

    func fetchHomeDashboard() async throws -> HomeDashboard {
        let token = try await teamAccessService.token()
        let response: WorkerHomeDashboardResponse = try await client.get(path: "/api/v1/t/\(token)")
        return HomeDashboard(response: response)
    }
}

private struct WorkerHomeDashboardResponse: Decodable {
    let weather: WorkerHomeWeather?
    let heatLevel: Int
    let checklistSummary: WorkerChecklistSummary
    let activeEmergencyCall: WorkerEmergencyCall?
}

private struct WorkerHomeWeather: Decodable {
    let temperature: Double?
    let humidity: Double?
    let apparentTemperature: Double?
}

private struct WorkerChecklistSummary: Decodable {
    let total: Int
    let completed: Int
}

private struct WorkerEmergencyCall: Decodable {}

struct HomeDashboard: Equatable {
    let weather: HomeWeather
    let todayRecordCount: Int
    let activeEmergencyCount: Int

    fileprivate init(response: WorkerHomeDashboardResponse) {
        weather = HomeWeather(
            temperature: response.weather?.temperature,
            humidity: response.weather?.humidity,
            apparentTemperature: response.weather?.apparentTemperature,
            heatLevel: response.heatLevel
        )
        todayRecordCount = response.checklistSummary.completed
        activeEmergencyCount = response.activeEmergencyCall == nil ? 0 : 1
    }

    static let unavailable = HomeDashboard(
        weather: HomeWeather(
            temperature: nil,
            humidity: nil,
            apparentTemperature: nil,
            heatLevel: 0
        ),
        todayRecordCount: 0,
        activeEmergencyCount: 0
    )

    private init(
        weather: HomeWeather,
        todayRecordCount: Int,
        activeEmergencyCount: Int
    ) {
        self.weather = weather
        self.todayRecordCount = todayRecordCount
        self.activeEmergencyCount = activeEmergencyCount
    }

    var recordStatusText: String {
        "오늘 기록 \(todayRecordCount)건 · 긴급 호출 \(activeEmergencyCount)건"
    }
}

struct HomeWeather: Equatable {
    let temperature: Double?
    let humidity: Double?
    let apparentTemperature: Double?
    let heatLevel: Int

    var heatLevelTitle: String {
        switch heatLevel {
        case 3: "폭염 위험 단계"
        case 2: "폭염 주의 단계"
        case 1: "폭염 관심 단계"
        default: "폭염 안전 단계"
        }
    }

    var temperatureText: String { measurementText(temperature, suffix: "°C") }
    var humidityText: String { measurementText(humidity, suffix: "%") }
    var apparentTemperatureText: String { measurementText(apparentTemperature, suffix: "°C") }
    var weatherStatusText: String { temperature == nil ? "정보 없음" : "현장 입력" }

    private func measurementText(_ value: Double?, suffix: String) -> String {
        guard let value else { return "—" }
        return "\(String(format: "%.1f", value))\(suffix)"
    }
}
